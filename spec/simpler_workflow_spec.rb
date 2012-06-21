require 'spec_helper'

describe SimplerWorkflow do

  let(:client) { AWS.config.simple_workflow_client }

  let(:describe_domain_response) { client.stub_for(:describe_domain) }
  let(:list_domains_response) {client.stub_for(:list_domains)}

  let(:domain) { SimplerWorkflow.domain("test-domain") }

  let(:domain_desc) {{
    'configuration' => { 'workflowExecutionRetentionPeriodInDays' => '2' },
    'domainInfo' => {
      'name' => domain.name,
      'description' => 'desc',
      'status' => 'REGISTERED',
    },
  }}

  let(:domains_desc) {
    {
      'domainInfos' => [
        domain_desc['domainInfo']
      ]
    }
  }

  context "Referring to a domain" do
    before :each do
      describe_domain_response.stub(:data).and_return(domain_desc)
      client.stub(:describe_domain).and_return(describe_domain_response)
      list_domains_response.stub(:data).and_return(domains_desc)
      client.stub(:list_domains).and_return(list_domains_response)
    end

    it "should return the domain for the test" do
      domain.should_not be_nil
      domain.should be_a(SimplerWorkflow::Domain)
    end

    it "should provide the domain name" do
      domain.name.should == "test-domain"
    end

    it "should show the default retention period" do
      domain.retention_period.should == 2
    end
  end
end
