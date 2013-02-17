module SimplerWorkflow
  class ActivityRegistry

    def register(name, version = nil, activity)
      case name
      when String
        name = name.to_sym
      when Array
        name, version = name
      when Hash
        name.symbolize_keys!
        version = name[:version]
        name = name[:name]
      end

      registry[[name,version]] = activity
    end

    alias :[]= :register


    def get(name, version=nil)
      case name
      when String
        name = name.to_sym
      when Hash
        name.symbolize_keys!
        version = name[:version]
        name = name[:name]
      when Array
        name, version = name
      end
      registry[[name, version]]
    end

    alias :[] :get
    
    protected
    def registry
      @registry ||= {}
    end
  end
end
