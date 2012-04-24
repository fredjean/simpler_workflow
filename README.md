# SimplerWorkflow

A wrapper around Amazon's Simple Workflow Service meant to simplify declaring and using activities and workflow. Provides some sane defaults
and work around some idiosyncracies of the platform.

## Installation

Add this line to your application's Gemfile:

    gem 'simpler_workflow'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install simpler_workflow

## Usage

### Configuring AWS Gem

We are using the aws-sdk gem to communicate with Amazon's service. You can configure the service by putting an ```aws.yml``` file
in your config directory. The file should contain the following information:

```yaml
development:
  access_key_id: <Amazon Acess Key ID>
  secret_access_key: <Amazon's secret access key>
```

This will authenticate your application or script against AWS and give you access to your SWF domain, workflows and activity.

### Access a domain

You will need to get a handle on a SWF domain before you can do anything else. Domains are accessed using the ```SimplerWorkflow::Domain```
class. This declares a domain that does not retain workflow execution data:

```ruby
domain = SimplerWorkflow::Domain["my-domain"]
```
An other option is to use the ```domains``` method to get a handle on a domain and pass a block. This allows you to write the following code:

```ruby
domain = SimplerWorkflow::Domain.domains("my_domain") do
  # Register activities
  register_activity(:an_activity, '1.0.0') do
    # See details below...
  end
  # Register workflow(s)
  register_workflow(:a_workflow, '1.1.0') do
    # See details below...
  end
end
```

You can also get a handle on a domain that retains information about workflow execution for 10 days with the following code:

```ruby
domain = SimplerWorkflow::Domain.new("my-domain", 10)
```

Domains are scoped by AWS accounts. The name of the domain must be unique within the account. You do not need to create the domain on AWS
since it is created the first time it is accessed.

### Creating an activity

Activities perform the work attached to the workflow and report back to SWF when the activity completes or it fails.

```SimplerWorkflow``` makes it easier to register an activity with your domain.

Activities must provide the following:
* A name
* A version
* Some code to run when it is invoked

You can also optionaly declare when what to do when the activity fails or succeeds.

```ruby
my_activity = domain.register_activity :my_activity, "1.0.0" do
  perform_activity do |task|
    input = task.input
    puts task
  end
end

my_activity.start_activity_loop
```

The activity manages a loop that waits for messages from SWF.

Activities are passed a task parameter. This parameter is provided to the activity by SWF and provides a lot of information about the task
at end. One item passed is the input attribute.

The block attached to the perform_activity method is called when the activity is invoked. This block contains the actions that an activity
will perform. The ```SimplerWorkflow::Activity``` class will automatically report that the activity completed successfully when the
block returns unless a response has been provided in the block. It will automatically report that an activity failed when an unhandled
exception is thrown within the block.

The activity can influence what happens when the activity succeeds or fail. You can specify the activity's failure response through the
```SimplerWorkflow::Activity#on_fail``` method. By default, the activity will ask the workflow to abort itself on failure. You can also
ask the workflow to repeat the activity by passing ```:retry``` to the method:

```ruby
my_activity = domain.register_activity :my_activity, "1.0.0" do
  on_fail :retry

  perform_activity do |task|
    # ...
  end
end
```

The activity can also tell a workflow what activity to trigger next on the workflow. This only works when using the default decision
loop (described later). This is done by declaring what is the next activity should be:

```ruby
my_activity = domain.register_activity :my_activity, "1.0.0" do
  on_success :my_next_activity, "1.0.0"

  perform_activity do |task|
    # ...
  end
end
```

### Workflow and Decision Loops

The next key concept in ```SimplerWorkflow``` is the workflow. The workflow decides what activities to invoke, what to do when
they complete and what to do when they fail. The ```SimplerWorkflow::Workflow``` object manages the decision loop.

By default, the workflow is setup to allow for a linear set of activities until the list runs out. This is convenient for simple
workflows. There are also hooks to override what happens with each decision point to accomodate more complex workflows.

Workflows are declared and registered through the ```SimplerWorkflow::Domain#register_workflow``` method.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
