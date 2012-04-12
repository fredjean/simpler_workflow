module SimplerWorkflow
  class WorkflowCollection
    def [](name, version)
      registry[[name,version]]
    end

    def []=(name, version, value)
      registry[[name, version]] = value
    end

    protected
    def registry
      @registry ||= {}
    end
  end
end
