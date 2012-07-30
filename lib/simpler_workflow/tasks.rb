# require 'simpler_workflow/tasks'
# will give you the simpler_workflow tasks.
# Much inspiration was derived from https://github.com/defunkt/resque

namespace :simpler_workflow do
  task :setup

  desc "Runs the workflows."
  task :work => [:preload, :setup] do
    require 'simpler_workflow'

    Signal.trap('QUIT') do
      SimplerWorkflow.child_processes.each do |child|
        Process.kill('QUIT', child)
      end
      exit(0)
    end

    Signal.trap('INT') do
      SimplerWorkflow.child_processes.each do |child|
        Process.kill('INT', child)
      end
      exit(0)
    end

    pattern = ENV['WORKFLOW'] || 'lib/workflow/*.rb'

    FileList.new(pattern).each do |f|
      load f
    end

    Process.waitall
  end

  desc "Preloads the Rails environment if this is running under Rails."
  task :preload => :setup do
    if defined?(Rails) && Rails.respond_to?(:application)
      # Rails 3
      Rails.application.eager_load!
    elsif defined?(Rails::Initializer)
      # Rails 2.3
      $rails_rake_task = false
      Rails::Initializer.run :load_application_classes
    end
  end
end

