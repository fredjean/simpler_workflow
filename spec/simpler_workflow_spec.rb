require 'spec_helper'

describe SimplerWorkflow do

  let(:client) { AWS.config.simple_workflow_client }

  let(:response) { client.stub_for(:list_domains) }

  let(:domain) { SimplerWorkflow.domain("test-domain") }

  let(:domain_desc) {{
    'configuration' => { 'workflowExecutionRetentionPeriodInDays' => '2' },
    'domainInfo' => {
      'name' => domain.name,
      'description' => 'desc',
      'status' => 'REGISTERED',
    },
  }}

  before :each do
    response.stub(:data).and_return(domain_desc)
    client.stub(:describe_domain).and_return(response)
  end

  it "should return the domain for the test" do
    domain.should_not be_nil
    domain.should be_a(SimplerWorkflow::Domain)
  end

  it "should provide the domain name" do
    domain.name.should == "test-domain"
  end

  it "should show the default retention period" do
    pending "Need to figure out how to stub this correctly."
    domain.retention_period.should == 2
  end
end
