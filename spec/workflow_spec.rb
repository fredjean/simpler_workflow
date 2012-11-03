require 'spec_helper'

module SimplerWorkflow
  describe Workflow do
    let(:client) { AWS.config.simple_workflow_client }
    let(:describe_domain_response) { client.stub_for(:describe_domain) }
    let(:list_domains_response) { client.stub_for(:list_domains) }

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

    before :each do
      describe_domain_response.stub(:data).and_return(domain_desc)
      client.stub(:describe_domain).and_return(describe_domain_response)
      list_domains_response.stub(:data).and_return(domains_desc)
      client.stub(:list_domains).and_return(list_domains_response)
    end

    context "Registering a new workflow." do
      before :each do 
        Workflow.send :public, :event_handlers
      end

      context "default workflows" do
        let(:workflow) { domain.register_workflow('test-workflow', '1.0.0') }

        let(:event_handlers) { workflow.event_handlers }
        it "should allow the registration of a domain." do
          workflow.name.should == 'test-workflow'
          workflow.version.should == '1.0.0'
        end

        it 'should have default handlers' do
          event_handlers.should_not be_nil
        end

        %w(WorkflowExecutionStarted ActivityTaskCompleted ActivityTaskFailed ActivityTaskTimedOut).each do |event|
          it "should have a default event handler for #{event}" do
            handler = event_handlers[event]
            handler.should_not be_nil
            handler.class.name.should == "SimplerWorkflow::Workflow::#{event}Handler"
          end
        end
      end
    end

  end
end
