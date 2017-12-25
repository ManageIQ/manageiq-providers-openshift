# instantiated at the end, for both classical and graph refresh
shared_examples "openshift refresher VCR tests" do
  let(:all_images_count) { 40 } # including /oapi/v1/images data
  let(:pod_images_count) { 12 } # only images mentioned by pods
  let(:images_managed_by_openshift_count) { 32 } # only images from /oapi/v1/images

  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    # env vars for easier VCR recording, see test_objects_record.sh
    hostname = ENV["API_HOST"] || "host.example.com"
    token = ENV["API_TOKEN"] || "theToken"

    @ems = FactoryGirl.create(
      :ems_openshift,
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

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openshift)
  end

  def normal_refresh
    VCR.use_cassette(described_class.name.underscore,
                     :match_requests_on => [:path,]) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems)
    end
  end

  def full_refresh_test
    2.times do
      @ems.reload
      normal_refresh
      @ems.reload

      assert_ems
      assert_table_counts
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
      assert_specific_used_container_image(:metadata => true)
      assert_specific_unused_container_image(:metadata => true, :archived => false)
    end
  end

  it "will perform a full refresh on openshift" do
    full_refresh_test
  end

  it 'will skip container_images if get_container_images = false' do
    stub_settings_merge(
      :ems_refresh => {:openshift => {:get_container_images => false}},
    )
    VCR.use_cassette(described_class.name.underscore,
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems)
    end

    @ems.reload

    expect(ContainerImage.count).to eq(pod_images_count)
    assert_specific_used_container_image(:metadata => false)
  end

  it 'will not delete previously collected metadata if get_container_images = false' do
    normal_refresh
    stub_settings_merge(
      :ems_refresh => {:openshift => {:get_container_images => false}},
    )
    VCR.use_cassette(described_class.name.underscore,
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems)
    end

    @ems.reload

    # Unused images are archived, metadata is retained either way.
    expect(@ems.container_images.count).to eq(pod_images_count)
    assert_specific_used_container_image(:metadata => true)
    assert_specific_unused_container_image(:metadata => true, :archived => true)
  end

  context "when refreshing an empty DB" do
    # To recreate both VCRs used here, use the script:
    # spec/vcr_cassettes/manageiq/providers/openshift/container_manager/test_objects_record.sh
    # which creates my-project-{0,1,2}.

    before(:each) do
      @key_route_label_mapping = FactoryGirl.create(:tag_mapping_with_category, :label_name => 'key-route-label')
      @key_route_label_category = @key_route_label_mapping.tag.category

      mode = ENV['RECORD_VCR'] == 'before_openshift_deletions' ? :new_episodes : :none
      VCR.use_cassette("#{described_class.name.underscore}_before_openshift_deletions",
                       :match_requests_on => [:path,], :record => mode) do
        EmsRefresh.refresh(@ems)
      end
    end

    let(:object_counts) do
      # using strings instead of actual model classes for compact rspec diffs
      {
        'ContainerProject'           => 10,
        'ContainerImage'             => 43,
        'ContainerRoute'             => 4,
        'ContainerTemplate'          => 20,
        'ContainerTemplateParameter' => 210,
        'ContainerReplicator'        => 8,
        'ContainerBuild'             => 3,
        'ContainerBuildPod'          => 3,
        'CustomAttribute'            => 622,
      }
    end

    it "saves the objects in the DB" do
      actual_counts = object_counts.collect { |k, _| [k, k.constantize.count] }.to_h
      expect(actual_counts).to eq(object_counts)

      expect(ContainerRoute.find_by(:name => "my-route-2").labels).to contain_exactly(
        label_with_name_value("key-route-label", "value-route-label")
      )
      expect(ContainerRoute.find_by(:name => "my-route-2").tags).to contain_exactly(
        tag_in_category_with_description(@key_route_label_category, "value-route-label")
      )
      expect(ContainerTemplate.find_by(:name => "my-template-2").container_template_parameters.count).to eq(1)
      ContainerBuildPod.all.each do |cbp|
        expect(cbp.container_group.container_project.name).to eq(cbp.namespace)
      end
    end

    context "when refreshing non empty DB" do
      # After deleting resources in the cluster:
      # "my-project-0" - The whole project
      # "my-project-1" - All resources inside the project
      # "my-project-2" - "my-pod-2", label of "my-route-2", parameters of "my-template-2"

      let(:extra_route_tags) { [] }

      before(:each) do
        # Simulate user assigning tags between 1st and 2nd refresh
        ContainerRoute.find_by(:name => "my-route-2").tags.concat(extra_route_tags)

        skip('meaningless at this stage of re-recording') if ENV['RECORD_VCR'] == 'before_openshift_deletions'

        mode = ENV['RECORD_VCR'] == 'after_openshift_deletions' ? :new_episodes : :none
        VCR.use_cassette("#{described_class.name.underscore}_after_openshift_deletions",
                         :match_requests_on => [:path,], :record => mode) do
          EmsRefresh.refresh(@ems)
        end
      end

      it "archives objects" do
        expect(ContainerProject.count).to eq(object_counts['ContainerProject'])
        expect(ContainerProject.active.count).to eq(object_counts['ContainerProject'] - 1)
        expect(ContainerProject.archived.count).to eq(1)

        # TODO: this varies by recording, in this recording only graph refresh has problem,
        # in some classical refresh had same problem, in some graph refresh archived 2 images...
        pending("why graph refresh DELETES 1 image from DB?") if Settings.ems_refresh.openshift.inventory_object_refresh
        expect(ContainerImage.count).to eq(object_counts['ContainerImage'])
        expect(ContainerImage.active.count).to eq(object_counts['ContainerImage'] - 1)
        expect(ContainerImage.archived.count).to eq(1)
      end

      it "removes the deleted objects from the DB" do
        # TODO: check whether these make sense
        deleted = {
          'ContainerRoute'             => 2,
          'ContainerTemplate'          => 2,
          'ContainerReplicator'        => 2,
          'ContainerBuild'             => 2,
          'ContainerBuildPod'          => 2,
          'CustomAttribute'            => 15,
          'ContainerTemplateParameter' => 3,
        }
        expected_counts = deleted.collect { |k, d| [k, object_counts[k] - d] }.to_h
        actual_counts = expected_counts.collect { |k, _| [k, k.constantize.count] }.to_h
        expect(actual_counts).to eq(expected_counts)

        expect(ContainerTemplate.find_by(:name => "my-template-0")).to be_nil
        expect(ContainerTemplate.find_by(:name => "my-template-1")).to be_nil

        expect(ContainerRoute.find_by(:name => "my-route-0")).to be_nil
        expect(ContainerRoute.find_by(:name => "my-route-1")).to be_nil

        expect(ContainerReplicator.find_by(:name => "my-replicationcontroller-0")).to be_nil
        expect(ContainerReplicator.find_by(:name => "my-replicationcontroller-1")).to be_nil

        expect(ContainerBuildPod.find_by(:name => "my-build-config-0-1")).to be_nil
        expect(ContainerBuildPod.find_by(:name => "my-build-config-1-1")).to be_nil

        expect(ContainerBuild.find_by(:name => "my-build-config-0", :namespace => "my-project-0")).to be_nil
        expect(ContainerBuild.find_by(:name => "my-build-config-1", :namespace => "my-project-1")).to be_nil

        expect(ContainerRoute.find_by(:name => "my-route-2").labels.count).to eq(0)
        expect(ContainerRoute.find_by(:name => "my-route-2").tags.count).to eq(0)
        expect(ContainerTemplate.find_by(:name => "my-template-2").container_template_parameters.count).to eq(0)
      end

      context "with user-assigned tags before 2nd refresh" do
        let(:extra_route_tags) { [@user_tag] }

        it "retains user tags when removing mapped tags" do
          expect(ContainerRoute.find_by(:name => "my-route-2").labels.count).to eq(0)
          expect(ContainerRoute.find_by(:name => "my-route-2").tags).to contain_exactly(@user_tag)
        end
      end

      it "disconnects container projects" do
        project0 = ContainerProject.find_by(:name => "my-project-0")
        project1 = ContainerProject.find_by(:name => "my-project-1")

        expect(project0).not_to be_nil
        expect(project0.deleted_on).not_to be_nil
        expect(project0.archived?).to be true
        expect(project0.container_groups.count).to eq(0)
        expect(project0.containers.count).to eq(0)

        expect(project1.container_groups.count).to eq(0)
        expect(project1.containers.count).to eq(0)
      end
    end
  end

  it 'will store only images used by pods if store_unused_images = false' do
    stub_settings_merge(
      :ems_refresh => {:openshift => {:store_unused_images => false}},
    )
    normal_refresh

    @ems.reload

    expect(ContainerImage.count).to eq(pod_images_count)
    assert_specific_used_container_image(:metadata => true)
  end

  it 'will not delete previously collected metadata if store_unused_images = false' do
    normal_refresh
    stub_settings_merge(
      :ems_refresh => {:openshift => {:store_unused_images => false}},
    )
    normal_refresh

    @ems.reload

    # Unused images are disconnected, metadata is retained either way.
    expect(@ems.container_images.count).to eq(pod_images_count)
    assert_specific_used_container_image(:metadata => true)
    assert_specific_unused_container_image(:metadata => true, :archived => true)
  end

  def assert_table_counts
    expect(ContainerGroup.count).to eq(20)
    expect(ContainerNode.count).to eq(2)
    expect(Container.count).to eq(20)
    expect(ContainerService.count).to eq(12)
    expect(ContainerPortConfig.count).to eq(23)
    expect(ContainerRoute.count).to eq(6)
    expect(ContainerProject.count).to eq(9)
    expect(ContainerBuild.count).to eq(3)
    expect(ContainerBuildPod.count).to eq(3)
    expect(ContainerTemplate.count).to eq(26)
    expect(ContainerImage.count).to eq(all_images_count)
    expect(ContainerImage.joins(:containers).distinct.count).to eq(pod_images_count)
    expect(ManageIQ::Providers::Openshift::ContainerManager::ContainerImage.count).to eq(images_managed_by_openshift_count)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :port => 8443,
      :type => "ManageIQ::Providers::Openshift::ContainerManager"
    )
  end

  def assert_specific_container
    @container = Container.find_by(:name => "deployer")
    expect(@container).to have_attributes(
      :name          => "deployer",
      :restart_count => 0,
    )
    expect(@container[:backing_ref]).not_to be_nil

    # Check the relation to container node
    expect(@container.container_group).to have_attributes(
      :name => "metrics-deployer-frcf1"
    )

    # TODO: move to kubernetes refresher test (needs cassette containing seLinuxOptions)
    expect(@container.security_context).to have_attributes(
      :se_linux_user  => nil,
      :se_linux_role  => nil,
      :se_linux_type  => nil,
      :se_linux_level => "s0:c6,c0"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by(:name => "metrics-deployer-frcf1")
    expect(@containergroup).to have_attributes(
      :name           => "metrics-deployer-frcf1",
      :restart_policy => "Never",
      :dns_policy     => "ClusterFirst",
    )

    # Check the relation to container node
    expect(@containergroup.container_node).to have_attributes(
      :name => "host2.example.com"
    )

    # Check the relation to containers
    expect(@containergroup.containers.count).to eq(1)
    expect(@containergroup.containers.last).to have_attributes(
      :name => "deployer"
    )

    expect(@containergroup.container_project).to eq(ContainerProject.find_by(:name => "openshift-infra"))
    expect(@containergroup.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    expect(@containernode).to have_attributes(
      :name          => "host.example.com",
      :lives_on_type => nil,
      :lives_on_id   => nil
    )

    expect(@containernode.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_services
    @containersrv = ContainerService.find_by(:name => "kubernetes")
    expect(@containersrv).to have_attributes(
      :name             => "kubernetes",
      :session_affinity => "ClientIP",
      :portal_ip        => "172.30.0.1"
    )

    expect(@containersrv.container_project).to eq(ContainerProject.find_by(:name => "default"))
    expect(@containersrv.ext_management_system).to eq(@ems)
    expect(@containersrv.container_image_registry).to be_nil
  end

  def assert_specific_container_image_registry
    @registry = ContainerImageRegistry.find_by(:name => "172.30.190.81")
    expect(@registry).to have_attributes(
      :name => "172.30.190.81",
      :host => "172.30.190.81",
      :port => "5000"
    )
    expect(@registry.container_services.first.name).to eq("docker-registry")

    expect(ContainerService.find_by(:name => "docker-registry").container_image_registry.name). to eq("172.30.190.81")
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by(:name => "python-project")
    expect(@container_pr).to have_attributes(
      :name         => "python-project",
      :display_name => "Python project",
    )

    expect(@container_pr.container_groups.count).to eq(5)
    expect(@container_pr.containers.count).to eq(5)
    expect(@container_pr.container_replicators.count).to eq(1)
    expect(@container_pr.container_routes.count).to eq(1)
    expect(@container_pr.container_services.count).to eq(1)
    expect(@container_pr.container_builds.count).to eq(1)
    expect(ContainerBuildPod.where(:namespace => @container_pr.name).count).to eq(1)
    expect(@container_pr.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_route
    @container_route = ContainerRoute.find_by(:name => "registry-console")
    expect(@container_route).to have_attributes(
      :name      => "registry-console",
      :host_name => "registry-console-default.router.default.svc.cluster.local"
    )

    expect(@container_route.container_service).to have_attributes(
      :name => "registry-console"
    )

    expect(@container_route.container_project).to have_attributes(
      :name    => "default"
    )

    expect(@container_route.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_build
    @container_build = ContainerBuild.find_by(:name => "python-project")
    expect(@container_build).to have_attributes(
      :name              => "python-project",
      :build_source_type => "Git",
      :source_git        => "https://github.com/openshift/django-ex.git",
      :output_name       => "python-project:latest",
    )

    expect(@container_build.container_project).to eq(ContainerProject.find_by(:name => "python-project"))
  end

  def assert_specific_container_build_pod
    # TODO: record 2 builds of same name in different projects
    @container_build_pod = ContainerBuildPod.find_by(:name => "python-project-1")
    expect(@container_build_pod).to have_attributes(
      :namespace                     => "python-project",
      :name                          => "python-project-1",
      :phase                         => "Complete",
      :reason                        => nil,
      :output_docker_image_reference => "172.30.190.81:5000/python-project/python-project:latest",
    )

    expect(@container_build_pod.container_build).to eq(
      ContainerBuild.find_by(:name => "python-project")
    )

    expect(@container_build_pod.container_group).to eq(
      ContainerGroup.find_by(:name => "python-project-1-build")
    )
    expect(@container_build_pod.container_group.container_build_pod).to eq(@container_build_pod)
  end

  def assert_specific_container_template
    @container_template = ContainerTemplate.find_by(:name => "hawkular-cassandra-node-emptydir")
    expect(@container_template).to have_attributes(
      :name             => "hawkular-cassandra-node-emptydir",
      :type             => "ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate",
      :resource_version => "871"
    )

    expect(@container_template.ext_management_system).to eq(@ems)
    expect(@container_template.container_project).to eq(ContainerProject.find_by(:name => "openshift-infra"))
    expect(@container_template.container_template_parameters.count).to eq(4)
    expect(@container_template.container_template_parameters.find_by(:name => "NODE")).to have_attributes(
      :description    => "The node number for the Cassandra cluster.",
      :display_name   => nil,
      :ems_created_on => nil,
      :value          => nil,
      :generate       => nil,
      :from           => nil,
      :required       => true,
    )
  end

  def assert_specific_unused_container_image(metadata:, archived:)
    # An image not mentioned in /pods, only in /images, built by openshift so it has metadata.
    @container_image = ContainerImage.find_by(:name => "openshift/nodejs-010-centos7")

    expect(@container_image.archived?).to eq(archived)
    expect(@container_image.environment_variables.count).to eq(metadata ? 10 : 0)
    expect(@container_image.labels.count).to eq(1)
    expect(@container_image.docker_labels.count).to eq(metadata ? 15 : 0)
  end

  def assert_specific_used_container_image(metadata:)
    # An image mentioned both in /pods and /images, built by openshift so it has metadata.
    @container_image = ContainerImage.find_by(:name => "python-project/python-project")

    expect(@container_image.ext_management_system).to eq(@ems)
    expect(@container_image.environment_variables.count).to eq(metadata ? 12 : 0)
    # TODO: for next recording, oc label some running, openshift-built image
    expect(@container_image.labels.count).to eq(0)
    expect(@container_image.docker_labels.count).to eq(metadata ? 19 : 0)
    if metadata
      expect(@container_image).to have_attributes(
        :architecture   => "amd64",
        :author         => nil,
        :command        => ["/usr/libexec/s2i/run"],
        :digest         => "sha256:9422207673100308c18bccead913007b76ca3ef48f3c6bb70ce5f19d497c1392",
        :docker_version => "1.10.3",
        :entrypoint     => ["container-entrypoint"],
        :exposed_ports  => {"tcp"=>"8080"},
        :image_ref      => "docker://172.30.190.81:5000/python-project/python-project@sha256:9422207673100308c18bccead913007b76ca3ef48f3c6bb70ce5f19d497c1392",
        :registered_on  => "Thu, 08 Dec 2016 06:14:59 UTC +00:00",
        :size           => 206_435_839,

        # TODO: tag is set by both kubernetes and openshift parsers, so it
        # regresses to kubernetes value with get_container_images=false.
        #:tag            => "latest",
      )
    end
  end

  def label_with_name_value(name, value)
    an_object_having_attributes(
      :section => 'labels', :source => 'kubernetes',
      :name => name, :value => value
    )
  end

  def tag_in_category_with_description(category, description)
    satisfy { |tag| tag.category == category && tag.classification.description == description }
  end
end

describe ManageIQ::Providers::Openshift::ContainerManager::Refresher do
  context "classical refresh" do
    before(:each) do
      stub_settings_merge(
        :ems_refresh => {:openshift => {:inventory_object_refresh => false}}
      )

      expect(ManageIQ::Providers::Openshift::ContainerManager::RefreshParser).not_to receive(:ems_inv_to_inv_collections)
    end

    include_examples "openshift refresher VCR tests"
  end

  context "graph refresh" do
    before(:each) do
      stub_settings_merge(
        :ems_refresh => {:openshift => {:inventory_object_refresh => true}}
      )

      expect(ManageIQ::Providers::Openshift::ContainerManager::RefreshParser).not_to receive(:ems_inv_to_hashes)
    end

    context "with :default saver" do
      before(:each) do
        stub_settings_merge(
          :ems_refresh => {:openshift => {:inventory_collections => {:saver_strategy => :default}}}
        )
      end

      # TODO: pending proper graph store_unused_images implemetation
      include_examples "openshift refresher VCR tests"
    end

    context "with :batch saver" do
      before(:each) do
        stub_settings_merge(
          :ems_refresh => {:openshift => {:inventory_collections => {:saver_strategy => :batch}}}
        )
      end

      # TODO: pending proper graph store_unused_images implemetation
      include_examples "openshift refresher VCR tests"
    end
  end
end
