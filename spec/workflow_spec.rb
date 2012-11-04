require 'spec_helper'

module SimplerWorkflow
  describe Workflow do
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

				context "The workflow's initial activity" do
					before :each do
						workflow.initial_activity :test_activity, '1.0.0'
					end


					it "should store the initial activity" do
						workflow.send(:initial_activity_type).should == domain.activity_types[:test_activity, '1.0.0']
					end

					it "should start a workflow based on the declared initial activity" do
						event = stub( :attributes => stub( :input => "Mary had a little lamb"))
						decision_task.should_receive(:schedule_activity_task).with(domain.activity_types[:test_activity, '1.0.0'], input: event.attributes.input)

						event_handlers[:WorkflowExecutionStarted].process(decision_task, event)
					end
				end

				context "An activity completed." do
					it "should complete an execution when there isn't a next activity declared" do
						event = stub(:attributes => {})
						decision_task.should_receive(:complete_workflow_execution).with(result: 'success')

						event_handlers[:ActivityTaskCompleted].process(decision_task, event)
					end

					it "should complete the execution if we have results but to not provide a next activity" do
						event = Map.new
						event.set(:attributes, :result, '{"blah":"Hello"}')

						decision_task.should_receive(:complete_workflow_execution).with(result: 'success')

						event_handlers[:ActivityTaskCompleted].process(decision_task, event)
					end

					it "should schedule the next activity if it is provided" do
						event = Map.new
						next_activity_param = { next_activity: { name: :test_activity, version: "1.0.0"}}
						event.set(:attributes, :result, next_activity_param.to_json)

						next_activity = workflow.domain.activity_types[:test_activity, '1.0.0']


						scheduled_event = Map.new
						scheduled_event.set(:attributes, :input, "mary had a little lamb")
						workflow.should_receive(:scheduled_event).with(decision_task, event).and_return(scheduled_event)

						decision_task.should_receive(:schedule_activity).with(next_activity, input: scheduled_event.attributes.input)

						event_handlers[:ActivityTaskCompleted].process(decision_task, event)
					end
				end

				context "An activity task failed" do
					it "should fail the workflow if details about the failure aren't provided" do
						event = Map.new
						event.set(:attributes, :blah, "mary had a little lamb")
						decision_task.should_receive(:fail_workflow_execution)

						event_handlers[:ActivityTaskFailed].process(decision_task, event)
					end

					it "should fail the execution if instructed to do so" do
						event = Map.new
						details = {failure_policy: :fail}
						event.set(:attributes, :details, details.to_json)

						decision_task.should_receive(:fail_workflow_execution)

						event_handlers[:ActivityTaskFailed].process(decision_task, event)
					end

					it "should cancel the execution if instructed to abort" do
						event = Map.new
						details = {failure_policy: :abort}
						event.set(:attributes, :details, details.to_json)

						decision_task.should_receive(:cancel_workflow_execution)

						event_handlers[:ActivityTaskFailed].process(decision_task, event)
					end

					it "should cancel the execution if instructed to do so" do
						event = Map.new
						details = {failure_policy: :cancel}
						event.set(:attributes, :details, details.to_json)

						decision_task.should_receive(:cancel_workflow_execution)

						event_handlers[:ActivityTaskFailed].process(decision_task, event)
					end

          it "should reschedule the activity if requested" do
            activity_type = domain.activity_types[:test_activity, "1.0.0"]
            event = Map.new
            details = {failure_policy: :retry}
            event.set(:attributes, :details, details.to_json)
            scheduled_event = Map.new
            scheduled_event.set(:attributes, :input, "Mary had a little lamb")
            scheduled_event.set(:attributes, :activity_type, activity_type)

            decision_task.should_receive(:schedule_activity_task).with(activity_type, input: scheduled_event.attributes.input)

            workflow.should_receive(:scheduled_event).at_least(1).times.with(decision_task, event).and_return(scheduled_event)

            event_handlers[:ActivityTaskFailed].process(decision_task, event)
          end

          it "should fail malformed details attribute" do
						event = Map.new
						event.set(:attributes, :details, "Mary had a little lamb")

						decision_task.should_receive(:fail_workflow_execution)

						event_handlers[:ActivityTaskFailed].process(decision_task, event)
          end
				end
      end
    end
  end
end
