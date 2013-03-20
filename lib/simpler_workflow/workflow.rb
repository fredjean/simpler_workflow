module SimplerWorkflow
  class Workflow
    include OptionsAsMethods

    attr_reader :task_list, :domain, :name, :version, :options, :initial_activity_type

    def initialize(domain, name, version, options = {})
      Workflow.workflows[[name, version]] ||= begin
        default_options = {
          :default_task_list => name,
          :default_task_start_to_close_timeout => 2 * 60,
          :default_execution_start_to_close_timeout => 2 * 60,
          :default_child_policy => :terminate
        }
        @options = default_options.merge(options)
        @domain = domain
        @name = name
        @version = version
        self
      end
    end

    def initial_activity(name, version = nil)
      activity = Activity[domain, name.to_sym, version]
      @initial_activity_type = activity.to_activity_type
    end

    def decision_loop
      SimplerWorkflow.child_processes << fork do

        $0 = "Workflow: #{name} #{version}"

        Signal.trap('QUIT') do
          logger.info("Received SIGQUIT")
          @time_to_exit = true
        end

        Signal.trap('INT') do 
          logger.info("Received SIGINT")
          Process.exit!(0)
        end

        if SimplerWorkflow.after_fork
          SimplerWorkflow.after_fork.call
        end

        loop do
          begin
            logger.info("Waiting for a decision task for #{name.to_s}, #{version} listening to #{task_list}")
            domain.decision_tasks.poll_for_single_task(task_list) do |decision_task|
              handle_decision_task(decision_task)
            end
            Process.exit 0 if @time_to_exit
          rescue Timeout::Error => e
            if @time_to_exit
              Process.exit 0
            else
              retry
            end
          rescue => e
            context = {
              :workflow => to_workflow_type
            }
            SimplerWorkflow.exception_reporter.report(e, context)
            raise e
          end
        end
      end
    end

    def task_list
      options[:default_task_list][:name].to_s
    end

    def to_workflow_type
      { :name => name, :version => version }
    end

    def start_workflow(input, options = {})
      options[:input] = input
      domain.workflow_types[name.to_s, version].start_execution(options)
    end

    def on_start_execution(&block)
      event_handlers['WorkflowExecutionStarted'] = WorkflowEventHandler.new(&block)
    end

    def on_activity_completed(&block)
      event_handlers['ActivityTaskCompleted'] = WorkflowEventHandler.new(&block)
    end

    def on_activity_failed(&block)
      event_handlers['ActivityTaskFailed'] = WorkflowEventHandler.new(&block)
    end

    def on_activity_timed_out(&block)
      event_handlers['ActivityTaskTimedOut'] = WorkflowEventHandler.new(&block)
    end

    def self.[](name, version)
      workflows[[name, version]]
    end

    def self.register(name, version, workflow)
      workflows[[name, version]] = workflow
    end

    def scheduled_event(decision_task, event)
      decision_task.scheduled_event(event)
    end

    def last_activity(decision_task, event)
      scheduled_event(decision_task, event).attributes.activity_type
    end

    def last_input(decision_task, event)
      scheduled_event(decision_task, event).attributes.input
    end

    protected
    def self.workflows
      @workflows ||= {}
    end

    def self.swf
      SimplerWorkflow.swf
    end

    def logger
      SimplerWorkflow.logger
    end

    def handle_decision_task(decision_task)
      decision_task.extend AWS::SimpleWorkflow::DecisionTaskAdditions
      logger.info("Received decision task")
      decision_task.new_events.each do |event|
        logger.info("Processing #{event.event_type}")
        event_handlers.fetch(event.event_type, DefaultEventHandler.new(self)).process(decision_task, event)
      end
    end

    def event_handlers
      @event_handlers ||= Map[
        :WorkflowExecutionStarted , WorkflowExecutionStartedHandler.new(self) , 
        :ActivityTaskCompleted    , ActivityTaskCompletedHandler.new(self)    , 
        :ActivityTaskFailed       , ActivityTaskFailedHandler.new(self)       , 
        :ActivityTaskTimedOut     , ActivityTaskTimedOutHandler.new(self)
        ]
    end

    class DefaultEventHandler
      attr_accessor :workflow

      def initialize(workflow)
        @workflow = workflow
      end

      def scheduled_event(*args)
        workflow.scheduled_event(*args)
      end

      def domain
        workflow.domain
      end

      def last_activity(*args)
        workflow.last_activity(*args)
      end

      def last_input(*args)
        workflow.last_input(*args)
      end

      def initial_activity_type
        workflow.initial_activity_type
      end

      def process(*args); end
    end

    class WorkflowEventHandler
      attr_accessor :handler
 
      def initialize(&block)
        @handler = block
      end

      def process(decision_task, event)
        handler.call(decision_task, event)
      end
    end

    class ActivityTaskTimedOutHandler < DefaultEventHandler
      def process(decision_task, event)
        case event.attributes.timeoutType
        when 'START_TO_CLOSE', 'SCHEDULE_TO_START', 'SCHEDULE_TO_CLOSE'
          last_activity_type = last_activity(decision_task, event)
          SimplerWorkflow.logger.info("Retrying activity #{last_activity_type.name} #{last_activity_type.version} due to timeout.")
          decision_task.schedule_activity_task last_activity_type, :input => last_input(decision_task, event)
        when 'HEARTBEAT'
          decision_task.fail_workflow_execution
        end
      end
    end

    class ActivityTaskFailedHandler < DefaultEventHandler
      def process(decision_task, event)
        last_activity_type = last_activity(decision_task, event)
        failed_activity = domain.activities[last_activity_type]
        
        case failed_activity.failure_policy
        when :abort, :cancel
          SimplerWorkflow.logger.info("Cancelling workflow execution.")
          decision_task.cancel_workflow_execution
        when :retry
          SimplerWorkflow.logger.info("Retrying activity #{last_activity_type.name} #{last_activity_type.version}")
          decision_task.schedule_activity_task last_activity_type, :input => last_input(decision_task, event)
        else
          SimplerWorkflow.logger.info("Failing the workflow execution.")
          decision_task.fail_workflow_execution
        end
      end
    end

    class ActivityTaskCompletedHandler < DefaultEventHandler
      def process(decision_task, event)
        last_activity_type = last_activity(decision_task, event)

        completed_activity = domain.activities[last_activity_type]

        if next_activity = completed_activity.next_activity
          activity_type = domain.activity_types[next_activity.name, next_activity.version]
          decision_task.schedule_activity activity_type, input: scheduled_event(decision_task, event).attributes.input
        else
          decision_task.complete_workflow_execution(result: 'success')
        end
      end
    end

    class WorkflowExecutionStartedHandler < DefaultEventHandler
      def process(decision_task, event)
        decision_task.schedule_activity_task initial_activity_type, input: event.attributes.input
      end
    end
  end
end
