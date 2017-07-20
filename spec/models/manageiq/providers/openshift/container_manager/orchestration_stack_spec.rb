describe ManageIQ::Providers::Openshift::ContainerManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_openshift) }
  let(:ctp) { FactoryGirl.create(:container_template_parameter, :name => 'var1', :value => 'p1', :required => true) }
  let(:container_template) do
    FactoryGirl.create(:container_template, :ems_id => ems.id).tap do |ct|
      ct.container_template_parameters = [ctp]
    end
  end
  let(:container_route) do
    {
      :kind       => "Route",
      :apiVersion => "v1",
      :miq_class  => ContainerRoute,
      :metadata   => {:name => "dotnet-example", :namespace => "provision-test", :uid => "135f11fa-55e5-11e7-8449-fa163e02640a", :creationTimestamp => "2017-06-20T18:20:01Z"}
    }
  end

  before { allow(described_class).to receive(:raw_create_stack).and_return([container_route]) }

  it '.create_stack' do
    stack    = described_class.create_stack(container_template, container_template.container_template_parameters.to_a, 'my-project')
    resource = stack.resources.first
    expect(resource.name).to              eq(container_route[:metadata][:name])
    expect(resource.ems_ref).to           eq(container_route[:metadata][:uid])
    expect(resource.start_time).to        eq(container_route[:metadata][:creationTimestamp])
    expect(resource.physical_resource).to eq(container_route[:metadata][:namespace])
    expect(resource.logical_resource).to  eq(container_route[:kind])
    expect(resource.resource_category).to eq(container_route[:miq_class].name)
    expect(resource.description).to       eq(container_route[:apiVersion])
  end
end
