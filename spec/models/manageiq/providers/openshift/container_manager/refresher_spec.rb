shared_examples "openshift refresher VCR tests" do
  let(:all_images_count) { 273 } # including /oapi/v1/images data
  let(:pod_images_count) { 74 } # only images mentioned by pods
  let(:images_managed_by_openshift_count) { 202 } # only images from /oapi/v1/images

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openshift)
  end

  def full_refresh_test
    2.times do
      ems.reload
      full_refresh
      ems.reload

      assert_table_counts
      assert_specific_container_group
      assert_specific_container
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
      EmsRefresh.refresh(ems)
    end

    ems.reload

    expect(ContainerImage.count).to eq(pod_images_count)
    assert_specific_used_container_image(:metadata => false)
  end

  it 'will not delete previously collected metadata if get_container_images = false' do
    full_refresh
    stub_settings_merge(
      :ems_refresh => {:openshift => {:get_container_images => false}},
    )
    VCR.use_cassette(described_class.name.underscore,
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
      EmsRefresh.refresh(ems)
    end

    ems.reload

    # Unused images are archived, metadata is retained either way.
    expect(ems.container_images.count).to eq(pod_images_count)
    assert_specific_used_container_image(:metadata => true)
    assert_specific_unused_container_image(:metadata => true, :archived => true)
  end

  context "when refreshing an empty DB" do
    # To recreate both VCRs used here, use the script:
    # spec/vcr_cassettes/manageiq/providers/openshift/container_manager/test_objects_record.sh
    # which creates my-project-{0,1,2}.

    before(:each) do
      @key_route_label_mapping = FactoryBot.create(:tag_mapping_with_category, :label_name => 'key-route-label')
      @key_route_label_category = @key_route_label_mapping.tag.classification

      mode = ENV['RECORD_VCR'] == 'before_deletions' ? :new_episodes : :none
      VCR.use_cassette("#{described_class.name.underscore}_before_deletions",
                       :match_requests_on => [:path,], :record => mode) do
        EmsRefresh.refresh(ems)
      end
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

        skip('meaningless at this stage of re-recording') if ENV['RECORD_VCR'] == 'before_deletions'

        mode = ENV['RECORD_VCR'] == 'after_deletions' ? :new_episodes : :none
        VCR.use_cassette("#{described_class.name.underscore}_after_deletions",
                         :match_requests_on => [:path,], :record => mode) do
          EmsRefresh.refresh(ems)
        end
      end

      it "archives objects" do
        expect(ContainerProject.count).to eq(object_counts['ContainerProject'])
        expect(ContainerProject.active.count).to eq(object_counts['ContainerProject'] - 1)
        expect(ContainerProject.archived.count).to eq(1)

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
          'CustomAttribute'            => 17,
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
        let(:extra_route_tags) { [user_tag] }

        it "retains user tags when removing mapped tags" do
          expect(ContainerRoute.find_by(:name => "my-route-2").labels.count).to eq(0)
          expect(ContainerRoute.find_by(:name => "my-route-2").tags).to contain_exactly(user_tag)
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
    full_refresh

    ems.reload

    expect(ContainerImage.count).to eq(pod_images_count)
    assert_specific_used_container_image(:metadata => true)
  end

  it 'will not delete previously collected metadata if store_unused_images = false' do
    full_refresh
    stub_settings_merge(
      :ems_refresh => {:openshift => {:store_unused_images => false}},
    )
    full_refresh

    ems.reload

    # Unused images are disconnected, metadata is retained either way.
    expect(ems.container_images.count).to eq(pod_images_count)
    assert_specific_used_container_image(:metadata => true)
    assert_specific_unused_container_image(:metadata => true, :archived => true)
  end

  def assert_table_counts
    expect(ContainerGroup.count).to eq(96)
    expect(ContainerNode.count).to eq(1)
    expect(Container.count).to eq(155)
    expect(ContainerService.count).to eq(95)
    expect(ContainerPortConfig.count).to eq(106)
    expect(ContainerRoute.count).to eq(13)
    expect(ContainerProject.count).to eq(74)
    expect(ContainerBuild.count).to eq(3)
    expect(ContainerBuildPod.count).to eq(3)
    expect(ContainerTemplate.count).to eq(127)
    expect(ContainerImage.count).to eq(all_images_count)
    expect(ContainerImage.joins(:containers).distinct.count).to eq(pod_images_count)
    expect(ManageIQ::Providers::Openshift::ContainerManager::ContainerImage.count).to eq(images_managed_by_openshift_count)
  end

  def assert_specific_container
    @container = Container.find_by(:name => "my-container", :container_group => @containergroup)
    expect(@container).to have_attributes(
      :type          => "ManageIQ::Providers::Openshift::ContainerManager::Container",
      :name          => "my-container",
      :restart_count => 0,
    )
    expect(@container[:backing_ref]).to be_nil

    # Check the relation to container node
    expect(@container.container_group).to have_attributes(
      :name => "my-pod-1"
    )

    # TODO: move to kubernetes refresher test (needs cassette containing seLinuxOptions)
    expect(@container.security_context).to have_attributes(
      :se_linux_user  => "username",
      :se_linux_role  => "admin",
      :se_linux_type  => "default",
      :se_linux_level => "s0:c123,c456"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by(:name => "my-pod-1")
    expect(@containergroup).to have_attributes(
      :type           => "ManageIQ::Providers::Openshift::ContainerManager::ContainerGroup",
      :name           => "my-pod-1",
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst",
    )

    # Check the relation to container node
    expect(@containergroup.container_node).to have_attributes(
      :name => "crc-nv4w7-master-0"
    )

    # Check the relation to containers
    expect(@containergroup.containers.count).to eq(1)
    expect(@containergroup.containers.last).to have_attributes(
      :name => "my-container"
    )

    expect(@containergroup.container_project).to eq(ContainerProject.find_by(:name => "my-project-1"))
    expect(@containergroup.ext_management_system).to eq(ems)
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    expect(@containernode).to have_attributes(
      :type          => "ManageIQ::Providers::Openshift::ContainerManager::ContainerNode",
      :name          => "crc-nv4w7-master-0",
      :lives_on_type => nil,
      :lives_on_id   => nil
    )

    expect(@containernode.ext_management_system).to eq(ems)
  end

  def assert_specific_container_services
    @containersrv = ContainerService.find_by(:name => "kubernetes")
    expect(@containersrv).to have_attributes(
      :name             => "kubernetes",
      :session_affinity => "None",
      :portal_ip        => "10.217.4.1"
    )

    expect(@containersrv.container_project).to eq(ContainerProject.find_by(:name => "default"))
    expect(@containersrv.ext_management_system).to eq(ems)
    expect(@containersrv.container_image_registry).to be_nil
    expect(@containersrv.container_service_port_configs.pluck(:name, :protocol, :port)).to contain_exactly(
      ["https", "TCP", 443]
    )
  end

  def assert_specific_container_image_registry
    @registry = ContainerImageRegistry.find_by(:name => "image-registry.openshift-image-registry.svc")
    expect(@registry).to have_attributes(
      :name => "image-registry.openshift-image-registry.svc",
      :host => "image-registry.openshift-image-registry.svc",
      :port => "5000"
    )
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by(:name => "my-project-0")

    expect(@container_pr.container_groups.count).to eq(2)
    expect(@container_pr.containers.count).to eq(2)
    expect(@container_pr.container_replicators.count).to eq(1)
    expect(@container_pr.container_routes.count).to eq(1)
    expect(@container_pr.container_services.count).to eq(3)
    expect(@container_pr.container_builds.count).to eq(1)
    expect(ContainerBuildPod.where(:namespace => @container_pr.name).count).to eq(1)
    expect(@container_pr.ext_management_system).to eq(ems)
  end

  def assert_specific_container_route
    @container_route = ContainerRoute.find_by(:name => "console")
    expect(@container_route).to have_attributes(
      :name      => "console",
      :host_name => "console-openshift-console.apps-crc.testing"
    )

    expect(@container_route.container_service).to have_attributes(
      :name => "console"
    )

    expect(@container_route.container_project).to have_attributes(
      :name => "openshift-console"
    )

    expect(@container_route.ext_management_system).to eq(ems)
  end

  def assert_specific_container_build
    @container_build = ContainerBuild.find_by(:name => "my-build-config-0")
    expect(@container_build).to have_attributes(
      :name              => "my-build-config-0",
      :build_source_type => "Git",
      :source_git        => "https://github.com/openshift/ruby-hello-world",
      :output_name       => "origin-ruby-sample:latest"
    )

    expect(@container_build.container_project).to eq(ContainerProject.find_by(:name => "my-project-0"))
  end

  def assert_specific_container_build_pod
    # TODO: record 2 builds of same name in different projects
    @container_build_pod = ContainerBuildPod.find_by(:name => "my-build-config-0-1")
    expect(@container_build_pod).to have_attributes(
      :namespace                     => "my-project-0",
      :name                          => "my-build-config-0-1",
      :phase                         => "Complete",
      :reason                        => nil,
      :output_docker_image_reference => "image-registry.openshift-image-registry.svc:5000/my-project-0/origin-ruby-sample:latest"
    )

    expect(@container_build_pod.container_build).to eq(
      ContainerBuild.find_by(:name => "my-build-config-0")
    )

    expect(@container_build_pod.container_group).to eq(
      ContainerGroup.find_by(:name => "my-build-config-0-1-build")
    )
    expect(@container_build_pod.container_group.container_build_pod).to eq(@container_build_pod)
  end

  def assert_specific_container_template
    @container_template = ContainerTemplate.find_by(:name => "my-template-0")
    expect(@container_template).to have_attributes(
      :name => "my-template-0",
      :type => "ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate"
    )

    expect(@container_template.ext_management_system).to eq(ems)
    expect(@container_template.container_project).to eq(ContainerProject.find_by(:name => "my-project-0"))
    expect(@container_template.container_template_parameters.count).to eq(1)
    expect(@container_template.container_template_parameters.find_by(:name => "MYPARAM")).to have_attributes(
      :description    => nil,
      :display_name   => nil,
      :ems_created_on => nil,
      :value          => "my-value",
      :generate       => nil,
      :from           => nil,
      :required       => nil
    )
  end

  def assert_specific_unused_container_image(metadata:, archived:)
    # An image not mentioned in /pods, only in /images, built by openshift so it has metadata.
    @container_image = ContainerImage.find_by(:name => "ubi7/ruby-30")

    expect(@container_image.archived?).to eq(archived)
    expect(@container_image.environment_variables.count).to eq(metadata ? 24 : 0)
    expect(@container_image.labels.count).to eq(0)
    expect(@container_image.docker_labels.count).to eq(metadata ? 23 : 0)
  end

  def assert_specific_used_container_image(metadata:)
    # An image mentioned both in /pods and /images, built by openshift so it has metadata.
    @container_image = ContainerImage.find_by(:name => "redhat/redhat-marketplace-index")

    expect(@container_image.ext_management_system).to eq(ems)
    expect(@container_image.environment_variables.count).to eq(0)
    # TODO: for next recording, oc label some running, openshift-built image
    expect(@container_image.labels.count).to eq(0)
    expect(@container_image.docker_labels.count).to eq(0)
    if metadata
      expect(@container_image).to have_attributes(
        :architecture   => nil,
        :author         => nil,
        :digest         => "sha256:48303b6bb3ff5eaa6f5649c479462304ce45c4c0186ae9da2767ab7920b4b01f",
        :docker_version => nil,
        :exposed_ports  => {},
        :image_ref      => "docker://registry.redhat.io/redhat/redhat-marketplace-index@sha256:48303b6bb3ff5eaa6f5649c479462304ce45c4c0186ae9da2767ab7920b4b01f",
        :registered_on  => nil,
        :size           => nil

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
  include Spec::Support::EmsRefreshHelper

  let(:ems) do
    # env vars for easier VCR recording, see test_objects_record.sh
    hostname = Rails.application.secrets.openshift[:hostname]
    token = Rails.application.secrets.openshift[:token]
    port = Rails.application.secrets.openshift[:port]

    FactoryBot.create(
      :ems_openshift_with_zone,
      :name                      => "OpenShiftProvider",
      :connection_configurations => [{:endpoint       => {:role              => :default,
                                                          :hostname          => hostname,
                                                          :port              => port,
                                                          :security_protocol => "ssl-without-validation"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )
  end

  let(:user_tag) { FactoryBot.create(:classification_cost_center_with_tags).entries.first.tag }

  describe "with OpenShift version v4" do
    let(:object_counts) do
      {
        'ContainerProject'           => 74,
        'ContainerImage'             => 273,
        'ContainerRoute'             => 13,
        'ContainerTemplate'          => 127,
        'ContainerTemplateParameter' => 942,
        'ContainerReplicator'        => 3,
        'ContainerBuild'             => 3,
        'ContainerBuildPod'          => 3,
        'CustomAttribute'            => 7704,
      }
    end

    [
      {:saver_strategy => "default"},
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

  context "Targeted refresh" do
    let(:kubeclient) { double("Kubeclient::Client") }
    before { full_refresh }

    it "doesn't impact unassociated records" do
      after_full_refresh = serialize_inventory

      namespace = Kubeclient::Resource.new(:metadata => {:name => "default", :uid => "fab45f64-009f-47a5-8a46-6894fc08f3c6", :labels => {:"kubernetes.io/metadata.name"=>"default"}, :creationTimestamp => '2022-11-20T08:02:38Z', :resourceVersion => '390'})
      allow(kubeclient).to receive(:get_namespace).and_return(namespace)
      allow(ems).to receive(:connect).and_return(kubeclient)

      targeted_refresh(
        %w[project route build build_config template image].map do |type|
          Kubeclient::Resource.new(:type => "MODIFIED", :object => load_watch_notice_data(type))
        end
      )

      assert_inventory_not_changed(after_full_refresh, serialize_inventory)
    end

    context "projects" do
      let(:project) { load_watch_notice_data("project") }
      let(:new_project) { load_watch_notice_data("new_project") }

      it "created" do
        namespace = Kubeclient::Resource.new(:metadata => {:name => "new-project", :uid => new_project.dig(:metadata, :uid)})
        allow(kubeclient).to receive(:get_namespace).and_return(namespace)
        allow(ems).to receive(:connect).and_return(kubeclient)

        targeted_refresh([Kubeclient::Resource.new(:type => "ADDED", :object => new_project)])

        expect(ems.container_projects.pluck(:ems_ref)).to include(new_project.dig(:metadata, :uid))
      end

      it "updated" do
        namespace = Kubeclient::Resource.new(:metadata => {:name => "default", :uid => project.dig(:metadata, :uid)})
        allow(kubeclient).to receive(:get_namespace).and_return(namespace)
        allow(ems).to receive(:connect).and_return(kubeclient)

        project[:metadata][:annotations]['openshift.io/display-name'] = "My Default Project"
        targeted_refresh([Kubeclient::Resource.new(:type => "MODIFIED", :object => project)])
        expect(ems.container_projects.find_by(:ems_ref => project.dig(:metadata, :uid)).display_name).to eq("My Default Project")
      end

      it "deleted" do
        targeted_refresh([Kubeclient::Resource.new(:type => "DELETED", :object => project)])
        expect(ems.container_projects.pluck(:ems_ref)).not_to include(project.dig(:metadata, :uid))
      end
    end

    context "routes" do
      let(:route) { load_watch_notice_data("route") }
      let(:new_route) { load_watch_notice_data("new_route") }

      it "created" do
        targeted_refresh([Kubeclient::Resource.new(:type => "ADDED", :object => new_route)])

        expect(ems.container_routes.pluck(:ems_ref)).to include(new_route.dig(:metadata, :uid))
      end

      it "updated" do
        route[:metadata][:name] = "java-server-updated"
        targeted_refresh([Kubeclient::Resource.new(:type => "MODIFIED", :object => route)])
        expect(ems.container_routes.find_by(:ems_ref => route.dig(:metadata, :uid)).name).to eq("java-server-updated")
      end

      it "deleted" do
        targeted_refresh([Kubeclient::Resource.new(:type => "DELETED", :object => route)])
        expect(ems.container_routes.pluck(:ems_ref)).not_to include(route.dig(:metadata, :uid))
      end
    end

    context "builds" do
      let(:build) { load_watch_notice_data("build") }
      let(:new_build) { load_watch_notice_data("new_build") }

      it "created" do
        targeted_refresh([Kubeclient::Resource.new(:type => "ADDED", :object => new_build)])

        expect(ems.container_build_pods.pluck(:ems_ref)).to include(new_build.dig(:metadata, :uid))
      end

      it "updated" do
        build[:status][:phase] = "Failed"
        targeted_refresh([Kubeclient::Resource.new(:type => "MODIFIED", :object => build)])
        expect(ems.container_build_pods.find_by(:ems_ref => build.dig(:metadata, :uid)).phase).to eq("Failed")
      end

      it "deleted" do
        targeted_refresh([Kubeclient::Resource.new(:type => "DELETED", :object => build)])
        expect(ems.container_build_pods.pluck(:ems_ref)).not_to include(build.dig(:metadata, :uid))
      end
    end

    context "build_configs" do
      let(:build_config) { load_watch_notice_data("build_config") }
      let(:new_build_config) { load_watch_notice_data("new_build_config") }

      it "created" do
        targeted_refresh([Kubeclient::Resource.new(:type => "ADDED", :object => new_build_config)])

        expect(ems.container_builds.pluck(:ems_ref)).to include(new_build_config.dig(:metadata, :uid))
      end

      it "updated" do
        build_config[:metadata][:name] = "python-project-updated"
        targeted_refresh([Kubeclient::Resource.new(:type => "MODIFIED", :object => build_config)])
        expect(ems.container_builds.find_by(:ems_ref => build_config.dig(:metadata, :uid)).name).to eq("python-project-updated")
      end

      it "deleted" do
        targeted_refresh([Kubeclient::Resource.new(:type => "DELETED", :object => build_config)])
        expect(ems.container_builds.pluck(:ems_ref)).not_to include(build_config.dig(:metadata, :uid))
      end
    end

    context "templates" do
      let(:template) { load_watch_notice_data("template") }
      let(:new_template) { load_watch_notice_data("new_template") }

      it "created" do
        targeted_refresh([Kubeclient::Resource.new(:type => "ADDED", :object => new_template)])

        expect(ems.container_templates.pluck(:ems_ref)).to include(new_template.dig(:metadata, :uid))
      end

      it "updated" do
        template[:metadata][:name] = "my-template-0-updated"
        targeted_refresh([Kubeclient::Resource.new(:type => "MODIFIED", :object => template)])
        expect(ems.container_templates.find_by(:ems_ref => template.dig(:metadata, :uid)).name).to eq("my-template-0-updated")
      end

      it "deleted" do
        targeted_refresh([Kubeclient::Resource.new(:type => "DELETED", :object => template)])
        expect(ems.container_templates.pluck(:ems_ref)).not_to include(template.dig(:metadata, :uid))
      end
    end

    def targeted_refresh(notices)
      collector = ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager::WatchNotice.new(ems, notices)
      persister = ManageIQ::Providers::Openshift::Inventory::Persister::ContainerManager::WatchNotice.new(ems, nil)
      parser    = ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager::WatchNotice.new

      parser.collector = collector
      parser.persister = persister
      parser.parse
      persister.persist!
    end

    def load_watch_notice_data(type)
      YAML.load_file("spec/models/manageiq/providers/openshift/container_manager/watches_data/#{type}.yml")
    end
  end

  def full_refresh
    VCR.use_cassette(described_class.name.underscore, :match_requests_on => [:path,]) do
      EmsRefresh.refresh(ems)
    end
  end
end
