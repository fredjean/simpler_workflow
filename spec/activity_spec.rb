require 'spec_helper'

module SimplerWorkflow
  describe Activity do
    let(:client) { AWS.config.simple_workflow_client }
    let(:describe_domain_response) { client.stub_for(:describe_domain) }
    let(:list_domains_response) { client.stub_for(:list_domains) }

    let(:decision_task) { mock(AWS::SimpleWorkflow::DecisionTask) }

    let(:domain) { SimplerWorkflow.domain('test-domain') }

    let(:domain_desc) {{
      'configuration' => { 'workflowExecutionRetentionPeriodInDays' => '2' },
      'domainInfo' => {
        'name' => domain.name,
        'description' => 'desc',
        'status' => 'REGISTERED',
      },
    }}

    let(:domains_desc) {
      {
        'domainInfos' => [
          domain_desc['domainInfo']
        ]
      }
    }

    let(:sdb) { AWS::SimpleDB.new }

    before :each do
      describe_domain_response.stub(:data).and_return(domain_desc)
      client.stub(:describe_domain).and_return(describe_domain_response)
      list_domains_response.stub(:data).and_return(domains_desc)
      client.stub(:list_domains).and_return(list_domains_response)
    end

    context "Registering a new activity" do
      context "default activity" do
        subject(:activity) { domain.register_activity('test-activity', '1.0.0') }

        its(:name) { should == 'test-activity' }
        its(:version) { should == '1.0.0' }
        its(:domain) { should == domain }
        its(:failure_policy) { should == :fail }
        its(:task_list) { should == 'test-activity' }
      end

      context "Setting the failure policy" do
        subject(:activity) do
          domain.register_activity('test-activity', '1.0.1') do
            on_fail :retry
          end
        end

        its(:failure_policy) { should == :retry }
      end

      context "Setting the next activity" do
        subject(:activity) do
          domain.register_activity('test-success', '1.0.0') do
            on_success 'next-activity', '1.0.0'
          end
        end

        its(:next_activity) { should == Activity[domain, 'next-activity', '1.0.0'] }
      end

      context "performing a task" do
        subject(:activity) do
          domain.register_activity('test-task', '1.0.0') do
            perform_activity do |task|
              task.complete! 'result' => "success"
            end
          end
        end

        it "should execute the task handler." do
          task = mock(AWS::SimpleWorkflow::ActivityTask)
          task.should_receive(:complete!).with("result" => "success")

          activity.perform_task(task)
        end
      end

      context "We should always return an activity from the registry" do
        subject(:activity) { Activity[domain, 'not-a-real-activity', '1.0.0'] }

        its(:name) { should == 'not-a-real-activity' }
        its(:version) { should == '1.0.0' }
        its(:failure_policy) { should == :fail }
      end

      context "We are retrieving an activity that was register in a different process" do
        subject(:activity) { Activity[domain, 'registered-somewhere-else', '1.0.0'] }

        it "should build the activity from the SDB data..." do
          Activity.activities.should_receive(:sdb_attributes).with(domain, "registered-somewhere-else-1.0.0").and_return({
            :failure_policy => 'retry',
            :next_activity_name => 'yet-another-activity',
            :next_activity_version => '1.0.0'
          })

          Activity.activities.should_receive(:sdb_attributes).with(domain, 'yet-another-activity-1.0.0').and_return({})

          activity.failure_policy.should == :retry
          activity.next_activity.should == Activity[domain, 'yet-another-activity', '1.0.0']
          activity.next_activity.failure_policy.should == :fail
        end

      end

      context "Just in case we get strings from amazon SDB..." do
        subject(:activity) { Activity[domain, 'registered-somewhere-else', '2.0.0'] }

        it "should build the activity from the SDB data... with Strings this time..." do
          Activity.activities.should_receive(:sdb_attributes).with(domain, "registered-somewhere-else-2.0.0").and_return({
            'failure_policy' => 'retry',
            'next_activity_name' => 'yet-another-activity',
            'next_activity_version' => '2.0.0'
          })

          Activity.activities.should_receive(:sdb_attributes).with(domain, 'yet-another-activity-2.0.0').and_return({})

          activity.failure_policy.should == :retry
          activity.next_activity.should == Activity[domain, 'yet-another-activity', '2.0.0']
          activity.next_activity.failure_policy.should == :fail
        end
      end
    end
  end
end
