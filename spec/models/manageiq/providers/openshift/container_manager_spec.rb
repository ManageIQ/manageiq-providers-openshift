describe ManageIQ::Providers::Openshift::ContainerManager do
  it "#catalog_types" do
    ems = FactoryBot.create(:ems_openshift)
    expect(ems.catalog_types).to include("generic_container_template")
  end
end
