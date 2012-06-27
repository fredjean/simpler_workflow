# -*- encoding: utf-8 -*-
require File.expand_path('../lib/simpler_workflow/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Frederic Jean"]
  gem.email         = ["fred@snugghome.com"]
  gem.description   = %q{A wrapper around Amazon's Simple Workflow Service}
  gem.summary       = %q{A wrapper and DSL around Amazon's Simple Workflow Service with the goal of making it almost pleasant to define workflows.}
  gem.homepage      = "https://github.com/SnuggHome/simpler_workflow"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "simpler_workflow"
  gem.require_paths = ["lib"]
  gem.version       = SimplerWorkflow::VERSION

  gem.add_dependency 'aws-sdk', '~> 1.5.0'
  gem.add_dependency 'map'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'ruby-debug'
  gem.add_development_dependency 'travis-lint'
end
