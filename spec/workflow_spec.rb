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

        it "should have a default tasklist" do
          workflow.task_list.should == workflow.name
        end

        it "should have a default task start to close timeout" do
          workflow.options[:default_task_start_to_close_timeout].should == "120"
        end

        it "should have a default execution start to close timeout" do
          workflow.options[:default_execution_start_to_close_timeout].should == "120"
        end

        it "should have a default child policy of terminate" do
          workflow.options[:default_child_policy].should == 'TERMINATE'
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

          it "should call the right handler for #{event}" do
            new_event = Map.new
            new_event.set(:event_type, event)

            decision_task.should_receive(:new_events).and_return([new_event])

            event_handlers[new_event.event_type].should_receive(:call).with(decision_task, new_event)

            workflow.send :handle_decision_task, decision_task
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

						event_handlers[:WorkflowExecutionStarted].call(decision_task, event)
					end
				end

				context "An activity completed." do
					it "should complete the execution if we have results but to not provide a next activity" do
						event = Map.new
						event.set(:attributes, :result, '{"blah":"Hello"}')

            scheduled_activity = domain.register_activity(:completion_activity, '1.0.0')

						scheduled_event = Map.new
						scheduled_event.set(:attributes, :input, "mary had a little lamb")
            scheduled_event.set(:attributes, :activity_type, scheduled_activity.to_activity_type)

            decision_task.should_receive(:scheduled_event).with(event).and_return(scheduled_event)
						decision_task.should_receive(:complete_workflow_execution).with(result: 'success')

						event_handlers[:ActivityTaskCompleted].call(decision_task, event)
					end

					it "should schedule the next activity if the current one declares one" do
						event = Map.new
						event.set(:attributes, :result, "success")

            test_activity = domain.register_activity(:test_activity, '1.0.0')

            scheduled_activity = domain.register_activity(:success_activity, '1.0.0') do
              on_success :test_activity, '1.0.0'
            end

						next_activity = test_activity.to_activity_type

						scheduled_event = Map.new
						scheduled_event.set(:attributes, :input, "mary had a little lamb")
            scheduled_event.set(:attributes, :activity_type, scheduled_activity.to_activity_type)

            decision_task.should_receive(:scheduled_event).with(event).twice.and_return(scheduled_event)
						decision_task.should_receive(:schedule_activity).with(next_activity, input: scheduled_event.attributes.input)

						event_handlers[:ActivityTaskCompleted].call(decision_task, event)
					end
				end

				context "An activity task failed" do
					it "should fail the execution if instructed to do so" do
						event = Map.new

            test_activity = domain.register_activity(:failed_activity, '1.0.0')

            scheduled_event = Map.new
            scheduled_event.set(:attributes, :input, "Mary had a little lamb")
            scheduled_event.set(:attributes, :activity_type, test_activity.to_activity_type)

						decision_task.should_receive(:fail_workflow_execution)
            decision_task.should_receive(:scheduled_event).with(event).and_return(scheduled_event)

						event_handlers[:ActivityTaskFailed].call(decision_task, event)
					end

					it "should cancel the execution if instructed to abort" do
						event = Map.new
            test_activity = domain.register_activity(:failed_activity, '1.0.1') do
              on_fail :abort
            end

            scheduled_event = Map.new
            scheduled_event.set(:attributes, :input, "Mary had a little lamb")
            scheduled_event.set(:attributes, :activity_type, test_activity.to_activity_type)

            decision_task.should_receive(:scheduled_event).with(event).and_return(scheduled_event)
						decision_task.should_receive(:cancel_workflow_execution)

						event_handlers[:ActivityTaskFailed].call(decision_task, event)
					end

					it "should cancel the execution if instructed to do so" do
						event = Map.new

            test_activity = domain.register_activity(:failed_activity, '1.0.2') do
              on_fail :cancel
            end

            scheduled_event = Map.new
            scheduled_event.set(:attributes, :input, "Mary had a little lamb")
            scheduled_event.set(:attributes, :activity_type, test_activity.to_activity_type)

            decision_task.should_receive(:scheduled_event).with(event).and_return(scheduled_event)
						decision_task.should_receive(:cancel_workflow_execution)

						event_handlers[:ActivityTaskFailed].call(decision_task, event)
					end

          it "should reschedule the activity if requested" do
            event = Map.new

            test_activity = domain.register_activity(:failed_activity, '1.0.3') do
              on_fail :retry
            end

            scheduled_event = Map.new
            scheduled_event.set(:attributes, :input, "Mary had a little lamb")
            scheduled_event.set(:attributes, :activity_type, test_activity.to_activity_type)

            decision_task.should_receive(:scheduled_event).with(event).twice.and_return(scheduled_event)
            decision_task.should_receive(:schedule_activity_task).with(test_activity.to_activity_type, input: scheduled_event.attributes.input)

            event_handlers[:ActivityTaskFailed].call(decision_task, event)
          end

				end

        context "an activity timed out" do
          %w(START_TO_CLOSE SCHEDULE_TO_CLOSE SCHEDULE_TO_START).each do |timeout_type|
            it "should retry a timed out decision task on #{timeout_type}" do
              activity_type = domain.activity_types[:test_activity, "1.0.0"]
              event = Map.new
              event.set(:attributes, :timeoutType, timeout_type)
              scheduled_event = Map.new
              scheduled_event.set(:attributes, :input, "Mary had a little lamb")
              scheduled_event.set(:attributes, :activity_type, activity_type)

              decision_task.should_receive(:scheduled_event).twice.and_return(scheduled_event)
              decision_task.should_receive(:schedule_activity_task).with(activity_type, input: scheduled_event.attributes.input)
              event_handlers[:ActivityTaskTimedOut].call(decision_task, event)
            end
          end

          it "should fail a workflow execution when the heartbeat fails" do
            event = Map.new
            event.set(:attributes, :timeoutType, 'HEARTBEAT')

            decision_task.should_receive(:fail_workflow_execution)

            event_handlers[:ActivityTaskTimedOut].call(decision_task, event)
          end
        end
      end
    end
  end
end
