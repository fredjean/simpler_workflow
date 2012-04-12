require 'aws-sdk'

module SimplerWorkflow
  def SimplerWorkflow.domain(domain_name)
    @domains ||= {}
    @domains[domain_name.to_sym] ||= Domain.new(domain_name)
  end

  def SimplerWorkflow.swf
    @swf ||= ::AWS::SimpleWorkflow.new
  end

  autoload :Version,  'simpler_workflow/version'
  autoload :Domain,   'simpler_workflow/domain'
  autoload :Workflow, 'simpler_workflow/workflow'
  autoload :Activity, 'simpler_workflow/activity'
end

class Map
  def Map.from_json(json)
    from_hash(JSON.parse(json))
  end
end
