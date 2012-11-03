# -*- encoding: utf-8 -*-
require File.expand_path('../lib/simpler_workflow/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Frederic Jean"]
  gem.email         = ["fred@snugghome.com"]
  gem.description   = %q{A wrapper around Amazon's Simple Workflow Service}
  gem.summary       = %q{A wrapper and DSL around Amazon's Simple Workflow Service with the goal of making it almost pleasant to define workflows.}
  gem.homepage      = "https://github.com/fredjean/simpler_workflow"
  gem.post_install_message =<<EOM
simpler_workflow #{SimplerWorkflow::VERSION}
========================

Have a look at https://github.com/fredjean/simpler_workflow/wiki/MIgrating-to-0.2.0 if you
are upgrading from a 0.1.x version of the gem. There is a fundamental change in how the 
activity and decision loops are run. You may need to adjust your application for this to work.

Thank you for installing simpler_workflow. I hope you find it useful.

-- Fred
EOM

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "simpler_workflow"
  gem.require_paths = ["lib"]
  gem.version       = SimplerWorkflow::VERSION
  gem.required_ruby_version = '>= 1.9.0'

  gem.add_dependency 'aws-sdk', '~> 1.6.0'
  gem.add_dependency 'map'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'travis-lint'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'pry-nav'
end
