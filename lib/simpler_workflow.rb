require 'aws-sdk'
require 'aws/simple_workflow/decision_task_additions'
require 'map'

module SimplerWorkflow
  extend self

  def domain(domain_name)
    @domains ||= {}
    @domains[domain_name.to_sym] ||= Domain.new(domain_name)
  end

  def swf
    @swf ||= ::AWS::SimpleWorkflow.new
  end

  def after_fork(&block)
    block ? (@after_fork = block) : @after_fork
  end

  attr_writer :after_fork

  autoload :Version,  'simpler_workflow/version'
  autoload :Domain,   'simpler_workflow/domain'
  autoload :Workflow, 'simpler_workflow/workflow'
  autoload :Activity, 'simpler_workflow/activity'
  autoload :OptionsAsMethods, 'simpler_workflow/options_as_methods'
end

class Map
  def Map.from_json(json)
    from_hash(JSON.parse(json))
  end
end
