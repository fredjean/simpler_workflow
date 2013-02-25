module SimplerWorkflow
  class ActivityRegistry
    def register(*activity_tuple)
      domain = activity_tuple.shift
      activity = activity_tuple.pop if activity_tuple.last.is_a?(Activity)
      raise "Activity missing from registration" unless activity

      registry_for_domain(domain)[activity_tuple] = activity
    end

    alias :[]= :register

    def get(*activity_tuple)
      domain = activity_tuple.shift
      
      if AWS::SimpleWorkflow::ActivityType === domain
        name = domain.name.to_sym
        version = domain.version
        domain = domain.domain
      else
        name = activity_tuple.first
        
        case name
        when Hash
          version = name[:version]
          name = name[:name]
        when String, Symbol
          version = activity_tuple.last
        end
      end

      registry_for_domain(domain)[[name, version]]
    end

    alias :[] :get

    def persist_attributes(activity)
      domain = Domain.for(activity.domain)

      sdb_domain(domain).items.create(activity.simple_db_name, activity.simple_db_attributes)
    end

    protected
    def registries
      @registries ||= {}
    end

    def registry_for_domain(domain)
      domain = Domain.for(domain)

      unless sdb_domain(domain).exists?
        sdb.domains.create(sdb_domain_name(domain))
      end

      registries[domain.name.to_sym] ||= {}
    end

    def sdb_domain_name(domain)
      "swf-#{domain.name}-activities"
    end

    def sdb_domain(domain)
      sdb.domains[sdb_domain_name(domain)]
    end

    def self.sdb
      @sdb ||= AWS::SimpleDB.new
    end

    def sdb
      self.class.sdb
    end
  end
end
