require 'spec_helper'

module SimplerWorkflow
  describe Domain do
    let(:client) { AWS.config.simple_workflow_client }

    let(:describe_domain_response) { client.stub_for(:describe_domain) }
    let(:list_domains_response) { client.stub_for(:list_domains) }

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

    before :each do
      describe_domain_response.stub(:data).and_return(domain_desc)
      client.stub(:describe_domain).and_return(describe_domain_response)
      list_domains_response.stub(:data).and_return(domains_desc)
      client.stub(:list_domains).and_return(list_domains_response)
    end

    context "Getting a handle to the domain without a block" do
      let(:domain_desc) {{
        'configuration' => { 'workflowExecutionRetentionPeriodInDays' => '2' },
        'domainInfo' => {
          'name' => domain.name,
          'description' => 'desc',
          'status' => 'REGISTERED',
        },
      }}

      let(:domain) { SimplerWorkflow::Domain.domains('test-domain')}

      it "should provide a handle to a domain" do
        domain.should be_a SimplerWorkflow::Domain
      end

      it "should provide the name" do
        domain.name.should == 'test-domain'
      end

      it "should have the default retention period" do
        domain.retention_period.should == 2
      end
    end

    context "Getting a handle to the domain with a custom retention period without a block" do
      let(:domain_desc) {{
        'configuration' => { 'workflowExecutionRetentionPeriodInDays' => '14' },
        'domainInfo' => {
          'name' => domain.name,
          'description' => 'desc',
          'status' => 'REGISTERED',
        },
      }}

      let(:domain) { SimplerWorkflow::Domain.domains('test-domain-14', 14)}

      it "should provide the domain name" do
        domain.name.should == 'test-domain-14'
      end

      it "should provide the specified retention period" do
        domain.retention_period.should == 14
      end
    end

    context "Getting a handle to the domain via the index operator" do
      let(:domain) { SimplerWorkflow::Domain['test-domain-17']}
      let(:domain_desc) {{
        'configuration' => { 'workflowExecutionRetentionPeriodInDays' => '2' },
        'domainInfo' => {
          'name' => domain.name,
          'description' => 'desc',
          'status' => 'REGISTERED',
        },
      }}

      it "should provide the name of the domain" do
        domain.name.should == 'test-domain-17'
      end

      it "should provide the default retention period" do
        domain.retention_period.should == 2
      end
    end

    context "Creating a new domain" do
      it "should create a new domain with the default retention period." do
        client.should_receive(:describe_domain).
            with(:name => 'test-domain-15').
            and_raise(AWS::SimpleWorkflow::Errors::UnknownResourceFault)

        client.should_receive(:register_domain).with(
          :name => 'test-domain-15', :workflow_execution_retention_period_in_days => '2')

        domain = SimplerWorkflow::Domain.domains('test-domain-15')
        domain.name.should == 'test-domain-15'
        domain.retention_period.should == 2
      end

      it "should create a new domain with the specified retention period" do
        client.should_receive(:describe_domain).
            with(:name => 'test-domain-16').
            and_raise(AWS::SimpleWorkflow::Errors::UnknownResourceFault)

        client.should_receive(:register_domain).with(
          :name => 'test-domain-16', :workflow_execution_retention_period_in_days => '7')

        domain = SimplerWorkflow::Domain.domains('test-domain-16', 7)
        domain.name.should == 'test-domain-16'
        domain.retention_period.should == 7
      end
    end
  end
end
