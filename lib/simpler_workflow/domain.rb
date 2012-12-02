module SimplerWorkflow
  class Domain
    def initialize(domain_name, retention_period = 2, &block)
      domain_name = domain_name.to_s
      @domain = swf.domains[domain_name]
      unless @domain.exists?
        @domain = swf.domains.create(domain_name, retention_period) rescue @domain
      end

      self.instance_eval(&block) if block_given?
    end

    def Domain.domains(domain_name, retention_period = 2, &block)
      @domains ||= {}
      @domains[domain_name] ||= Domain.new(domain_name, retention_period)
      @domains[domain_name].instance_eval(&block) if block_given?
      @domains[domain_name]
    end

    def Domain.[](domain_name)
      Domain.domains(domain_name)
    end

    def register_workflow(name, version, &block)
      unless workflow = Workflow[name, version]
        workflow = Workflow.new(self, name, version)

        workflow.instance_eval(&block) if block_given?

        begin
          self.domain.workflow_types.register(name, version, workflow.options)
        rescue ::AWS::SimpleWorkflow::Errors::TypeAlreadyExistsFault
          # Instance already registered...
        end
      end

      workflow
    end

    def workflows
      Workflow
    end

    def start_workflow(name, version, input)
      logger.info("Starting workflow[#{name},#{version}]")
      workflow = Workflow[name, version] || Workflow.new(self, name, version)
      workflow.start_workflow(input)
    end

    def activities
      Activity
    end

    def activity_types
      domain.activity_types
    end

    def register_activity(name, version, &block)
      unless activity = Activity[name, version]
        logger.info("Registering Activity[#{name},#{version}]")
        activity = Activity.new(self, name, version)

        activity.instance_eval(&block) if block

        begin
          self.domain.activity_types.register(name.to_s, version, activity.options)
        rescue ::AWS::SimpleWorkflow::Errors::TypeAlreadyExistsFault
          # Nothing to do, should probably log something here...
        end
      end

      activity
    end

    def method_missing(meth_name, *args)
      if domain.respond_to?(meth_name.to_sym)
        domain.send(meth_name.to_sym, *args)
      else
        super
      end
    end

    protected
    def swf
      SimplerWorkflow.swf
    end

    def domain
      @domain
    end

    def logger
      $logger || Rails.logger
    end
  end
end
