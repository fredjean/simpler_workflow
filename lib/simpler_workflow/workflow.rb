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
      if activity = Activity[name.to_sym, version]
        @initial_activity_type = activity.to_activity_type
      elsif activity = domain.activity_types[name.to_s, version]
        @initial_activity_type = activity
      end
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
              :workflow_execution => decision_task.workflow_execution,
              :workflow => to_workflow_type,
              :decision_task => decision_task
            }
            SimplerWorkflow.exception_reporter.report(e, context)
            raise e
          end
        end
      end
    end

    def task_list
      @options[:default_task_list][:name].to_s
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
      event_handler['ActivityTaskCompleted'] = WorkflowEventHandler.new(&block)
    end

    def on_activity_failed(&block)
      event_handler['ActivityTaskFailed'] = WorkflowEventHandler.new(&block)
    end

    def on_activity_timed_out(&block)
      event_handler['ActivityTaskTimedOut'] = WorkflowEventHandler.new(&block)
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

    protected
    def self.workflows
      @workflows ||= {}
    end

    def self.swf
      SimplerWorkflow.swf
    end

    def last_activity(decision_task, event)
      scheduled_event(decision_task, event).attributes.activity_type
    end

    def last_input(decision_task, event)
      scheduled_event(decision_task, event).attributes.input
    end

    def logger
      SimplerWorkflow.logger
    end

    def handle_decision_task(decision_task)
      decision_task.extend AWS::SimpleWorkflow::DecisionTaskAdditions
      logger.info("Received decision task")
      decision_task.new_events.each do |event|
        logger.info("Processing #{event.event_type}")
        event_handlers[event.event_type].process
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

    class WorkflowEventHandler
      attr_accessor :handler

      def initialize(&block)
        @handler = block
      end

      def process(decision_task, event)
        handler.call(decision_task, event)
      end
    end

    class ActivityTaskTimedOutHandler
      attr_accessor :workflow

      def initialize(workflow)
        @workflow = workflow
      end

      def process(decision_task, event)
        case event.attributes.timeoutType
        when 'START_TO_CLOSE', 'SCHEDULE_TO_START', 'SCHEDULE_TO_CLOSE'
          logger.info("Retrying activity #{last_activity(decision_task, event).name} #{last_activity(decision_task, event).version} due to timeout.")
          decision_task.schedule_activity_task last_activity(decision_task, event), :input => last_input(decision_task, event)
        when 'HEARTBEAT'
          decision_task.cancel_workflow_execution
        end
      end

      protected
      def last_activity(*args)
        workflow.last_activity(*args)
      end

      def last_input(*args)
        workflow.last_input(*args)
      end
    end

    class ActivityTaskFailedHandler
      attr_accessor :workflow

      def initialize(workflow)
        @workflow = workflow
      end

      def process(decision_task, event)
        if event.attributes.has_key?(:details)
          details = Map.from_json(event.attributes.details)
          case details.failure_policy.to_sym
          when :abort, :cancel
            decision_task.cancel_workflow_execution
          when :fail
            decision_task.fail_workflow_execution
          when :retry
            logger.info("Retrying activity #{last_activity(decision_task, event).name} #{last_activity(decision_task, event).version}")
            decision_task.schedule_activity_task last_activity(decision_task, event), :input => last_input(decision_task, event)
          end
        else
          decision_task.fail_workflow_execution
        end
      end
    end

    class ActivityTaskCompletedHandler
      attr_accessor :workflow

      def initialize(workflow)
        @workflow = workflow
      end

      def process(decision_task, event)
        if event.attributes.has_key?(:result)
          result = Map.from_json(event.attributes.result)
          if next_activity = result[:next_activity]
            activity_type = domain.activity_types[next_activity[:name], next_activity[:version]]
            decision_task.schedule_activity activity_type, input: scheduled_event(decision_task, event).attributes.input
          else
            decision_task.complete_workflow_execution(result: 'success')
          end
        else
          SimplerWorkflow.logger.info("Workflow #{workflow.name}, #{workflow.version} completed")
          decision_task.complete_workflow_execution result: 'success'
        end
      end

      protected
      def scheduled_event(*args)
        workflow.scheduled_event(*args)
      end

      def domain
        workflow.domain
      end
    end

    class WorkflowExecutionStartedHandler
      attr_accessor :workflow

      def initialize(workflow)
        @workflow = workflow
      end

      def process(decision_task, event)
        decision_task.schedule_activity_task initial_activity_type, input: event.attributes.input
      end

      protected
      def initial_activity_type
        workflow.initial_activity_type
      end
    end
  end
end
