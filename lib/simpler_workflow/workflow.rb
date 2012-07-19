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
      fork do

        $0 = "SWF: #{name} #{version}"

        if SimplerWorkflow.after_fork
          SimplerWorkflow.after_fork.call
        end

        begin
          logger.info("Starting decision loop for #{name.to_s}, #{version} listening to #{task_list}")
          domain.decision_tasks.poll(task_list) do |decision_task|
            logger.info("Received decision task")
            decision_task.new_events.each do |event|
              logger.info("Processing #{event.event_type}")
              case event.event_type
              when 'WorkflowExecutionStarted'
                start_execution(decision_task, event)
              when 'ActivityTaskCompleted'
                activity_completed(decision_task, event)
              when 'ActivityTaskFailed'
                activity_failed(decision_task, event)
              when 'ActivityTaskTimedOut'
                activity_timed_out(decision_task, event)
              end
            end
          end
        rescue Timeout::Error => e
          retry
        end
      end
    end

    def task_list
      @options[:default_task_list][:name].to_s
    end

    def start_execution(decision_task, event)
      logger.info "Starting the execution of the job."
      if @on_start_execution && @on_start_execution.respond_to?(:call)
        @on_start_execution.call(decision_task, event)
      else
        decision_task.schedule_activity_task initial_activity_type, :input => event.attributes.input
      end
    end

    def activity_completed(decision_task, event)
      if @on_activity_completed && @on_activity_completed.respond_to?(:call)
        @on_activity_completed.call(decision_task, event)
      else
        if event.attributes.keys.include?(:result)
          result = Map.from_json(event.attributes.result)
          next_activity = result[:next_activity]
          activity_type = domain.activity_types[next_activity[:name], next_activity[:version]]
          decision_task.schedule_activity_task activity_type, :input => scheduled_event(decision_task, event).attributes.input
        else
          logger.info("Workflow #{name}, #{version} completed")
          decision_task.complete_workflow_execution :result => 'success'
        end
      end
    end

    def activity_failed(decision_task, event)
      logger.info("Activity failed.")
      if @on_activity_failed && @on_activity_failed.respond_to?(:call)
        @on_activity_failed.call(decision_task, event)
      else
        if event.attributes.keys.include?(:details)
          details = Map.from_json(event.attributes.details)
          case details.failure_policy.to_sym
          when :abort
            decision_task.cancel_workflow_execution
          when :retry
            logger.info("Retrying activity #{last_activity(decision_task, event).name} #{last_activity(decision_task, event).version}")
            decision_task.schedule_activity_task last_activity(decision_task, event), :input => last_input(decision_task, event)
          end
        else
          decision_task.cancel_workflow_execution
        end
      end
    end

    def activity_timed_out(decision_task, event)
      logger.info("Activity timed out.")
      if @on_activity_timed_out && @on_activity_timed_out.respond_to?(:call)
        @on_activity_timed_out.call(decision_task, event)
      else
        case event.attributes.timeoutType
        when 'START_TO_CLOSE', 'SCHEDULE_TO_START', 'SCHEDULE_TO_CLOSE'
          logger.info("Retrying activity #{last_activity(decision_task, event).name} #{last_activity(decision_task, event).version} due to timeout.")
          decision_task.schedule_activity_task last_activity(decision_task, event), :input => last_input(decision_task, event)
        when 'HEARTBEAT'
          decision_task.cancel_workflow_execution
        end
      end
    end

    def start_workflow(input, options = {})
      options[:input] = input
      domain.workflow_types[name.to_s, version].start_execution(options)
    end

    def on_start_execution(&block)
      @on_start_execution = block
    end

    def on_activity_completed(&block)
      @on_activity_completed = block
    end

    def on_activity_failed(&block)
      @on_activity_failed = block
    end

    def on_activity_timed_out(&block)
      @on_activity_timed_out = block
    end

    def self.[](name, version)
      workflows[[name, version]]
    end

    def self.register(name, version, workflow)
      workflows[[name, version]] = workflow
    end

    protected
    def self.workflows
      @workflows ||= {}
    end

    def self.swf
      SimplerWorkflow.swf
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

    def logger
      $logger || Rails.logger
    end
  end
end
