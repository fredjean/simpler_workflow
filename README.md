# SimplerWorkflow

A wrapper around Amazon's Simple Workflow Service meant to simplify declaring and using activities and workflow. Provides some sane defaults.

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

You can also get a handle on a domain that retains information about workflow execution for 10 days with the following code:

```ruby
domain = SimplerWorkflow::Domain.new("my-domain", 10)
```

Domains are scoped by AWS accounts. The name of the domain must be unique within the account. You do not need to create the domain on AWS
since it is created the first time it is accessed.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
