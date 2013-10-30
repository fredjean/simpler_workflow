module SimplerWorkflow

	module ParentProcess

		# This class is aimed to be used with daemons gem or something similar
		# it launches as many workers as required, which is just running the on boot time block n times
		# a sample daemon using daemons gem would like this:

		#	#!/usr/bin/env/ ruby
		#	require 'rubygems'
		#	require 'bundler/setup'
		#	require 'daemons'
		#	dirmode = :normal
		#	# Check if we're in a deployment machine
		#	# to store logs in /var/run or in the app folder
		#	if ENV['ENV']
		#		log_dir = "/var/log/swf"
		#		pid_dir = "/var/run/swf"
		#	else
		#		log_dir = File.expand_path '../log/', __FILE__
		#		pid_dir = File.expand_path '../log/pid', __FILE__
		#	end
		#	script_path = File.expand_path '../boot.rb', __FILE__
		#	Daemons.run script_path, {
		#		:app_name   => "credibanco_daemon",
		#		:dir_mode   => dirmode,
		#		:log_dir	=> log_dir,
		#		:dir        => pid_dir,
		#		:multiple   => false,
		#		:monitor    => true,
		#		:log_output => true,
		#		# backtrace causes errors detecting as uncatched
		#		# some correctly handled exceptions. Keep disabled.
		#		:backtrace  => false
		#  	}


		require 'fileutils'

		def self.extended(base)

			$logger = Logger.new STDOUT
			
			base.extend ClassMethods

			Signal.trap('TERM') { base.graceful_exit 'QUIT'}

			Signal.trap('INT') { base.graceful_exit 'INT'}
			
		end

		module ClassMethods

			def graceful_exit(s)
				SimplerWorkflow.child_processes.each do |child| 
					Process.kill(s, child)
				end
			end
			
			def workers(val)
				@workers = val
			end

			def log_level(val)
				@log_level = val
			end

			def on_boot(&block)
					$logger.level = @log_level if @log_level
					# separate this execution in the log
					$logger.info "Booting with #{@workers} workers----------------------------"
					@workers.times { yield }
					# we wait for all children processes to exit; when QUIT is sent
					# we terminate them and this will automatically exit.
					Process.waitall
				
			end

		end
	end
end