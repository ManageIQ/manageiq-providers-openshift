describe ManageIQ::Providers::Openshift::ContainerManager do
  it "#supported_catalog_types" do
    ems = FactoryBot.create(:ems_openshift)
    expect(ems.supported_catalog_types).to match_array(%w(generic_container_template))
  end
end
