module SimplerWorkflow
  class Activity
    include OptionsAsMethods

    attr_reader :domain, :name, :version, :options, :next_activity

    def initialize(domain, name, version, options = {})
      Activity.activities[[name, version]] ||= begin
        default_options = {
          :default_task_list => name,
          :default_task_start_to_close_timeout => 5 * 60,
          :default_task_schedule_to_start_timeout => 5 * 60,
          :default_task_schedule_to_close_timeout => 10 * 60,
          :default_task_heartbeat_timeout => :none
        }
        @options = default_options.merge(options)
        @domain = domain
        @name = name
        @version = version
        @failure_policy = :abort
        self
      end
    end

    def on_success(activity, version = nil)
      case activity
      when Hash
        activity.symbolize_keys!
        name = activity[:name].to_sym
        version = activity[:version]
      when String
        name = activity.to_sym
      when Symbol
        name = activity
      end
      @next_activity = { :name => name, :version => version }
    end

    def on_fail(failure_policy)
      @failure_policy = failure_policy.to_sym
    end

    def failure_policy
      @failure_policy || :abort
    end

    def perform_activity(&block)
      @perform_task = block
    end

    def perform_task(task)
      logger.info("Performing task #{name}")
      @perform_task.call(task)
    rescue => e
      logger.error e.message
      logger.error e.backtrace.join("\n")
      task.fail! :reason => e.message[0..250], :details => {:failure_policy => failure_policy}.to_json
    end

    def to_activity_type
      domain.activity_types[name.to_s, version]
    end

    def start_activity_loop
      fork do

        $0 = "Activity: #{name} #{version}"

        if SimplerWorkflow.after_fork
          SimplerWorkflow.after_fork.call
        end

        loop do
          begin
            logger.info("Starting activity_loop for #{name}")
            domain.activity_tasks.poll(name.to_s) do |task|
              logger.info("Received task...")
              perform_task(task)
              unless task.responded?
                if next_activity
                  result = {:next_activity => next_activity}.to_json
                  task.complete!(:result => result)
                else
                  task.complete!
                end
              end
            end
          rescue Timeout::Error => e
          rescue => e
            logger.error(e.message)
            logger.error(e.backtrace.join("\n"))
          end
        end
      end
    end

    def poll_for_single_task
      logger.info("Polling for single task for #{name}")
      domain.activity_tasks.poll_for_single_task(name.to_s)
    end

    def count
      domain.activity_tasks.count(name).to_i
    end

    def self.[](name, version = nil)
      case name
      when String
        name = name.to_sym
      when Hash
        name.symbolize_keys!
        version = name[:version]
        name = name[:name]
      end
      activities[[name, version]]
    end

    def self.register(name, version, activity)
      activities[[name, version]] = activity
    end

    protected
    def self.activities
      @activities ||= {}
    end

    def self.swf
      SimplerWorkflow.swf
    end

    def logger
      $logger || Rails.logger
    end
  end
end
