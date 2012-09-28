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

  def logger
    $logger || Rails.logger
  end

  def exception_reporter(&block)
    if block_given?
      @exception_reporter = DefaultExceptionReporter.new(&block)
    end

    @exception_reporter || DefaultExceptionReporter.new
  end

  def exception_reporter=(exception_handler)
    @exception_reporter = exception_handler
  end

  autoload :Version,  'simpler_workflow/version'
  autoload :Domain,   'simpler_workflow/domain'
  autoload :Workflow, 'simpler_workflow/workflow'
  autoload :Activity, 'simpler_workflow/activity'
  autoload :OptionsAsMethods, 'simpler_workflow/options_as_methods'
  autoload :DefaultExceptionReporter, 'simpler_workflow/default_exception_reporter'
end

class Map
  def Map.from_json(json)
    from_hash(JSON.parse(json))
  end
end
