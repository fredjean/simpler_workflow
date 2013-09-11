module SimplerWorkflow

	module ParentProcess

		require 'fileutils'

		def self.extended(base)
			
			base.extend ClassMethods

			# Define some defaults. 
			# They can be overwritten using the convenience methods
			base.logfile_path "log/#{base.to_s.downcase}.log"
			# put the ephimeral data in pid folder
			base.pidfile_path "log/pid/#{base.to_s.downcase}.pid"
			base.lockfile_path "log/pid/#{base.to_s.downcase}.lock"

			# By using USR1 instead of the QUIT signal, we ensure that
			# this process will only close if all it's children are terminated
			# this convention avoids zombie processes.
			Signal.trap('USR1') { base.graceful_exit 'QUIT'}

			Signal.trap('INT') { base.graceful_exit 'INT'}
			
		end

		module ClassMethods

			def graceful_exit(s)
				SimplerWorkflow.child_processes.each do |child| 
					Process.kill(s, child)
				end
				# I really don't know why this still executes
				# if all children are terminated, however it
				# seems to work. Most likely ruby wait for the whole
				# method to finish.
				$logger.close
				# prevent problems for future boots
				@lockfile.close #flock(File::LOCK_UN)

			end
			
			def workers(val)
				@workers = val
			end

			def pidfile_path(val)
				@pidfile_path = val
			end

			def lockfile_path(val)
				@lockfile_path = val
			end

			def logfile_path(val)
				@logfile_path = val
			end

			def log_level(val)
				@log_level = val
			end

			# handle lock, pidfile_path and takes care of children
			# is a slightly more elaborated loop trigger with
			# elements from the rake tasks and bin/swf
			def on_boot(&block)
				
				pid = Integer(IO.read(@pidfile_path).strip) rescue nil
				running = begin; Process.kill(0, pid); true; rescue Object; false; end
				if running
					# custom exit code captured in the rake task
					exit 42
				else
					File.open(@pidfile_path, "w") { |f| f.write(Process.pid) }
				end
				
				@lockfile = File.open(@lockfile_path, "w")
				if @lockfile.flock(File::LOCK_EX | File::LOCK_NB)
					# If we're ready to run, prepare the logger
					$logger = Logger.new(@logfile_path)
					$logger.level = @log_level if @log_level
					# separate this execution in the log
					$logger.info "Booting with #{@workers} workers----------------------------"
					@workers.times { yield }
					# we wait for all children processes to exit; when QUIT is sent
					# we terminate them and this will automatically exit.
					Process.waitall
				else
					# custom exit code captured in the rake task
					exit 43
				end
			end

		end
	end
end