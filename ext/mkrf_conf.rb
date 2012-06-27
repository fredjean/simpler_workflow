require 'rubygems'
require 'rubygems/command.rb'
require 'rubygems/dependency_installer.rb'

begin
  Gem::Command.build_args = ARGV
rescue NoMethodError
end

inst = Gem::DependencyInstaller.new
begin
  if RUBY_VERSION < "1.9"
    inst.install "ruby-debug", "~> 0.10.3"
  else
    inst.install "ruby-debug19", "~> 0.11.24"
  end

  if RUBY_PLATFORM =~ /java/i
    inst.install "jruby-openssl"
  end
rescue
  exit(1)
end

f = File.open(File.join(File.dirname(__FILE__), "Rakefile"), "w")   # create dummy rakefile to indicate success
f.write("task :default\n")
f.closeeset
