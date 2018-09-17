# instantiated at the end, for both classical and graph refresh
shared_examples "openshift refresher VCR tests" do
  let(:all_images_count) { 40 } # including /oapi/v1/images data
  let(:pod_images_count) { 12 } # only images mentioned by pods
  let(:images_managed_by_openshift_count) { 32 } # only images from /oapi/v1/images

  before(:each) do
    # env vars for easier VCR recording, see test_objects_record.sh
    hostname = ENV["OPENSHIFT_MASTER_HOST"] || "host.example.com"
    token    = ENV["OPENSHIFT_MANAGEMENT_ADMIN_TOKEN"] || "theToken"

    @ems = FactoryGirl.create(
      :ems_openshift_with_zone,
      :name                      => "OpenShiftProvider",
      :connection_configurations => [{:endpoint       => {:role              => :default,
                                                          :hostname          => hostname,
                                                          :port              => "8443",
                                                          :security_protocol => "ssl-without-validation"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )

    @user_tag = FactoryGirl.create(:classification_cost_center_with_tags).entries.first.tag
  end

  def normal_refresh
    VCR.use_cassette(described_class.name.underscore + '_inventory_object',
                     :allow_unused_http_interactions => true,
                     :match_requests_on => [:path,]) do # , :record => :new_episodes) do

      collector = ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager.new(@ems, @ems)
      persister = ManageIQ::Providers::Openshift::Inventory::Persister::ContainerManager.new(@ems)

      inventory = ::ManageIQ::Providers::Inventory.new(
        persister,
        collector,
        [ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager.new]
      )

      inventory.parse.persist!
    end
  end

  def full_refresh_test
    2.times do
      @ems.reload
      normal_refresh
      @ems.reload

      assert_counts
      assert_specific_container
      assert_specific_container_group
      assert_specific_container_node
      assert_specific_container_services
      assert_specific_container_image_registry
      assert_specific_container_project
      assert_specific_container_route
      assert_specific_container_build
      assert_specific_container_build_pod
      assert_specific_container_template
      assert_specific_service_offering
      assert_specific_used_container_image(:metadata => true)
      assert_specific_unused_container_image(:metadata => true, :archived => false)
    end
  end

  it "will perform a full refresh on openshift" do
    full_refresh_test
  end

  def base_inventory_counts
    {
      :container_group           => 58,
      :container_node            => 0,
      :container                 => 0,
      :container_port_config     => 0,
      :container_route           => 0,
      :container_project         => 18,
      :container_build           => 0,
      :container_build_pod       => 0,
      :container_template        => 188,
      :container_image           => 0,
      :service_class             => 183,
      :service_parameters_set    => 186,
      :openshift_container_image => 0,
    }
  end

  def assert_counts
    assert_table_counts(base_inventory_counts)
  end

  def assert_table_counts(expected_table_counts)
    actual = {
      :container_group           => ContainerGroup.count,
      :container_node            => ContainerNode.count,
      :container                 => Container.count,
      :container_port_config     => ContainerPortConfig.count,
      :container_route           => ContainerRoute.count,
      :container_project         => ContainerProject.count,
      :container_build           => ContainerBuild.count,
      :container_build_pod       => ContainerBuildPod.count,
      :container_template        => ContainerTemplate.count,
      :container_image           => ContainerImage.count,
      :service_class             => ServiceOffering.count,
      :service_parameters_set    => ServiceParametersSet.count,
      :openshift_container_image => ManageIQ::Providers::Openshift::ContainerManager::ContainerImage.count,
    }
    expect(actual).to match expected_table_counts
  end

  def assert_specific_container
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by(:name => "manageiq-backend-0")
    expect(@containergroup).to(
      have_attributes(
        :name           => "manageiq-backend-0",
        :restart_policy => "Always",
        :dns_policy     => "ClusterFirst",
        :phase          => "Running",
      )
    )

    # Check the relation to container node
    # TODO(lsmola) collect and test

    # Check the relation to containers
    # TODO(lsmola) collect and test

    expect(@containergroup.container_project).to eq(ContainerProject.find_by(:name => "miq-demo"))
    expect(@containergroup.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_node
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_services
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_image_registry
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by(:name => "default")
    expect(@container_pr).to(
      have_attributes(
        :name         => "default",
        :display_name => nil,
      )
    )

    expect(@container_pr.container_groups.count).to eq(3)
    expect(@container_pr.container_templates.count).to eq(0)
    # TODO(lsmola) how do we add link to projects?
    # expect(@container_pr.service_offerings.count).to eq(0)
    # expect(@container_pr.service_parameters_sets.count).to eq(0)
    expect(@container_pr.containers.count).to eq(0)
    expect(@container_pr.container_replicators.count).to eq(0)
    expect(@container_pr.container_routes.count).to eq(0)
    expect(@container_pr.container_services.count).to eq(0)
    expect(@container_pr.container_builds.count).to eq(0)
    expect(ContainerBuildPod.where(:namespace => @container_pr.name).count).to eq(0)
    expect(@container_pr.ext_management_system).to eq(@ems)

    @another_container_pr = ContainerProject.find_by(:name => "miq-demo")
    expect(@another_container_pr.container_groups.count).to eq(5)
    expect(@another_container_pr.container_templates.count).to eq(1)
    # TODO(lsmola) how do we add link to projects?
    # expect(@another_container_pr.service_offerings.count).to eq(0)
    # expect(@another_container_pr.service_parameters_sets.count).to eq(0)
    expect(@another_container_pr.containers.count).to eq(0)
    expect(@another_container_pr.container_replicators.count).to eq(0)
    expect(@another_container_pr.container_routes.count).to eq(0)
    expect(@another_container_pr.container_services.count).to eq(0)
    expect(@another_container_pr.container_builds.count).to eq(0)
    expect(ContainerBuildPod.where(:namespace => @another_container_pr.name).count).to eq(0)
    expect(@another_container_pr.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_route
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_build
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_build_pod
    # TODO(lsmola) collect and test
  end

  def assert_specific_container_template
    @container_template = ContainerTemplate.find_by(:ems_ref => "d0d2324c-a16e-11e8-ba7e-d094660d31fb")
    expect(@container_template).to(
      have_attributes(
        :name             => "manageiq",
        :type             => "ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate",
        :resource_version => "33819516"
      )
    )

    expect(@container_template.ext_management_system).to eq(@ems)
    expect(@container_template.container_project).to eq(ContainerProject.find_by(:name => "miq-demo"))
    expect(@container_template.container_template_parameters.count).to eq(43)
    expect(@container_template.container_template_parameters.find_by(:name => "NAME")).to(
      have_attributes(
        :description    => "The name assigned to all of the frontend objects defined in this template.",
        :display_name   => "Name",
        :ems_created_on => nil,
        :value          => "manageiq",
        :generate       => nil,
        :from           => nil,
        :required       => true,
      )
    )
  end

  def assert_specific_service_offering
    @service_offering = ServiceOffering.find_by(:name => "mariadb-persistent")
    @service_parameters_set = @service_offering.service_parameters_sets.first

    expect(@service_offering).to(
      have_attributes(
        :type => "ManageIQ::Providers::Openshift::ContainerManager::ServiceOffering",
        :name => "mariadb-persistent"
      )
    )
    expect(@service_offering.extra["spec"]).not_to be_nil
    expect(@service_offering.extra["status"]).not_to be_nil
    expect(@service_offering.service_parameters_sets.count).to eq(1)
    expect(@service_offering).to(
      eq(@service_parameters_set.service_offering)
    )

    # Relation to ServiceParametersSet
    expect(@service_parameters_set).to(
      have_attributes(
        :type        => "ManageIQ::Providers::Openshift::ContainerManager::ServiceParametersSet",
        :name        => "default",
        :description => "Default plan",
      )
    )
    expect(@service_parameters_set.extra["spec"]).not_to be_nil
    expect(@service_parameters_set.extra["status"]).not_to be_nil
  end

  def assert_specific_unused_container_image(metadata:, archived:)
    # TODO(lsmola) collect and test
  end

  def assert_specific_used_container_image(metadata:)
    # TODO(lsmola) collect and test
  end
end

describe ManageIQ::Providers::Openshift::ContainerManager::Refresher do
  context "graph refresh" do
    before(:each) do
      stub_settings_merge(
        :ems_refresh => {:openshift => {:inventory_object_refresh => true}}
      )
    end

    [
      {:saver_strategy => "batch", :use_ar_object => true},
      {:saver_strategy => "batch", :use_ar_object => false}
    ].each do |saver_options|
      context "with #{saver_options}" do
        before(:each) do
          stub_settings_merge(
            :ems_refresh => {:openshift => {:inventory_collections => saver_options}}
          )
        end

        include_examples "openshift refresher VCR tests"
      end
    end
  end
end
