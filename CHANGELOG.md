0.2.0
=====

Switches from running activity and decision loops in a thread to running
them as child process. This will simplify monitoring the different loops
and provide insulation from the other loops.

* Adds ```simpler_workflow:work``` rake task to locate, load and run the
  activity and decision loops.
* Adds the option to perform an action after forking a child process.
* Adds a swf script used to manage the workflow. The following actions
  are supported:
  * *start* - Start the activity and decision loops located under
    lib/workflow as a daemon
  * *run* - runs the activity and decision loops without daemonizing
    them.
  * *stop* - stops the activity and decision loops.
  * *pstree* - shows the child processes
  * *shutdown* - shuts down the activity and decision loops
  * *tail* - tails the logs associated with the workflow.
* Preloads the Rails environment (if running under Rails) to reduce the
  amount of time spent loading it after forking. May also reduce the
  memory footprint of the application by sharing memory (on some
  platform).

Migrating to 0.2.0
------------------

The workflow definitions should stay the same. You can either choose to
use the ```swf``` script to manage the workflows, build on top of the ```simpler_workflow:work``` 
rake task or keep your existing scripts.

You will need to add ```Process.waitall``` to prevent the parent
process from exiting prematurely. 

Using the ```SimplerWorkflow.after_fork``` method
-------------------------------------------------

You can use the ```SimplerWorkflow.after_form``` method to perform
actions after the child processes have been forked. This is useful to
re-establish ActiveRecord connections when using PostgreSQL for example.
Here's an example of this usage:

```ruby
SimplerWorkflow.after_fork do
  ActiveRecord::Base.establish_connection
end
```
  
It's usage is very similar to Resque's usage. 
