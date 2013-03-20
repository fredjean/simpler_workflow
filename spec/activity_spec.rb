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
    end
  end
end
