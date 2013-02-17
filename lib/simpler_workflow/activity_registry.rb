module SimplerWorkflow
  class ActivityRegistry
    def register(*activity_tuple)
      domain = activity_tuple.shift
      activity = activity_tuple.pop

      registry_for_domain(domain)[activity_tuple] = activity
    end

    alias :[]= :register


    def get(*activity_tuple)
      domain = activity_tuple.shift

      registry_for_domain(domain)[activity_tuple]
    end

    alias :[] :get
    
    protected
    def registries
      @registries ||= {}
    end

    def registry_for_domain(domain)
      domain = case domain
               when String, Symbol
                 Domain[domain.to_sym]
               when Domain
                 domain
               when AWS::SimpleWorkflow::Domain
                 Domain[domain.name.to_sym]
               end

      unless sdb.domains["swf-#{domain.name}-activities"].exists?
        sdb.domains.create("swf-#{domain.name}-activities")
      end

      registries[domain.name.to_sym] ||= {}
    end

    def self.sdb
      @sdb ||= AWS::SimpleDB.new
    end

    def sdb
      self.class.sdb
    end
  end
end
