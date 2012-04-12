# -*- encoding: utf-8 -*-
require File.expand_path('../lib/simpler_workflow/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Frederic Jean"]
  gem.email         = ["fred@snugghome.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "simpler_workflow"
  gem.require_paths = ["lib"]
  gem.version       = SimplerWorkflow::VERSION

  gem.add_dependency 'aws-sdk', '~> 1.3.6'
  gem.add_dependency 'map'
  gem.add_development_dependency 'rspec'
end
