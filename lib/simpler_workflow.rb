require 'aws-sdk'
require 'aws/simple_workflow/decision_task_additions'
require 'map'

require 'simpler_workflow/tasks' if defined?(Rake)

module SimplerWorkflow
  extend self

  # Provides a handle to a domain.
  def domain(domain_name)
    @domains ||= {}
    @domains[domain_name.to_sym] ||= Domain.new(domain_name)
  end

  # Provides a handle to the SimpleWorkflow underlying service.
  def swf
    @swf ||= ::AWS::SimpleWorkflow.new
  end

  # The logger used. Falls back to the Rails logger.
  def logger
    $logger || Rails.logger
  end

  # Sets the code to be called after a process fork when a block is provided.
  # Returns the previously set block (or nil) otherwise.
  #
  # @param block The block that will be called after a process is forked.
  # @return Proc the block that was passed earlier (or nil)
  def after_fork(&block)
    block ? (@after_fork = block) : @after_fork
  end
  attr_writer :after_fork

  # The list of child processes that have been forked from the main process.
  def child_processes
    @child_processes ||= []
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
  autoload :ActivityRegistry, 'simpler_workflow/activity_registry'
  autoload :OptionsAsMethods, 'simpler_workflow/options_as_methods'
  autoload :DefaultExceptionReporter, 'simpler_workflow/default_exception_reporter'
end
