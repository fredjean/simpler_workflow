module SimplerWorkflow

	module ParentProcess

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

			# handle lock, pidfile_path and takes care of children
			# is a slightly more elaborated loop trigger with
			# elements from the rake tasks and bin/swf
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