# instantiated at the end, for both classical and graph refresh
shared_examples "openshift refresher inventory_object VCR tests" do
  let(:all_images_count) { 40 } # including /oapi/v1/images data
  let(:pod_images_count) { 12 } # only images mentioned by pods
  let(:images_managed_by_openshift_count) { 32 } # only images from /oapi/v1/images

  before(:each) do
    # env vars for easier VCR recording, see test_objects_record.sh
    hostname = ENV["OPENSHIFT_MASTER_HOST"] || "host.example.com"
    token    = ENV["OPENSHIFT_MANAGEMENT_ADMIN_TOKEN"] || "theToken"

    @ems = FactoryBot.create(
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

    @user_tag = FactoryBot.create(:classification_cost_center_with_tags).entries.first.tag
  end

  def full_refresh
    VCR.use_cassette(described_class.name.underscore + '_inventory_object',
                     :allow_unused_http_interactions => true,
                     :match_requests_on              => [:path,]) do # , :record => :new_episodes) do

      collector = ManageIQ::Providers::Openshift::Inventory::Collector::ContainerManager.new(@ems, @ems)
      parser    = ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager.new
      persister = ManageIQ::Providers::Openshift::Inventory::Persister::ContainerManager.new(@ems)

      inventory = ManageIQ::Providers::Inventory.new(persister, collector, [parser])
      inventory.parse.persist!
    end
  end

  def targeted_refresh(notices = [])
    collector = ManageIQ::Providers::Openshift::Inventory::Collector::Watches.new(@ems, notices)
    persister = ManageIQ::Providers::Openshift::Inventory::Persister::TargetCollection.new(@ems)
    parser    = ManageIQ::Providers::Openshift::Inventory::Parser::Watches.new

    inventory = ManageIQ::Providers::Inventory.new(persister, collector, [parser])
    inventory.parse.persist!
  end

  def full_refresh_tests
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
    assert_specific_service_instance
    assert_specific_service_offering
    assert_specific_used_container_image(:metadata => true)
    assert_specific_unused_container_image(:metadata => true, :archived => false)
  end

  def targeted_refresh_delete_tests(deleted_pod_ems_ref)
    @ems.reload

    expect(@ems.container_groups.count).to eq(base_inventory_counts[:container_group] - 1)
    deleted_pod = ContainerGroup.find_by(:ems_id => @ems.id, :ems_ref => deleted_pod_ems_ref)
    expect(deleted_pod.archived?).to be_truthy
  end

  it "will perform a full refresh on openshift" do
    2.times do
      full_refresh
      full_refresh_tests
    end
  end

  it "will perform a targeted refresh of a pod on openshift" do
    full_refresh
    full_refresh_tests

    # NOTE: this object is from the full refresh, I have deleted most of the
    # other metadata/spec/status to keep the cruft down since we're only parsing
    # the uid.
    notice = Kubeclient::Resource.new(
      :type   => "DELETED",
      :object => {
        :kind       => "Pod",
        :apiVersion => "v1",
        :metadata => {:name => "manageiq-0", :generateName => "manageiq-", :namespace => "insights", :selfLink => "/api/v1/namespaces/insights/pods/manageiq-0", :uid => "331830bc-9f3a-11e8-ba7e-d094660d31fb", :resourceVersion => "32782622", :creationTimestamp => "2018-08-13T20:48:14Z", :deletionTimestamp => "2018-09-19T13:22:47Z", :labels => {:"controller-revision-hash" => "manageiq-675d87f7c", :name => "manageiq", :"statefulset.kubernetes.io/pod-name" => "manageiq-0"}, :annotations => {:"openshift.io/scc"=>"anyuid"}, :ownerReferences => [{:apiVersion => "apps/v1beta1", :kind => "StatefulSet", :name => "manageiq", :uid => "331593ab-9f3a-11e8-ba7e-d094660d31fb", :controller => true, :blockOwnerDeletion => true}]}, :spec => {:volumes => [{:name => "manageiq-server", :persistentVolumeClaim => {:claimName=>"manageiq-server-manageiq-0"}}, {:name => "miq-orchestrator-token-qlg96", :secret => {:secretName => "miq-orchestrator-token-qlg96", :defaultMode => 420}}], :containers => [{:name => "manageiq", :image => "docker.io/carbonin/manageiq-pods:frontend-latest-hammer", :ports => [{:containerPort => 80, :protocol => "TCP"}], :env => [{:name => "ALLOW_INSECURE_SESSION", :value => "true"}, {:name => "APPLICATION_ADMIN_PASSWORD", :valueFrom => {:secretKeyRef=>{:name => "manageiq-secrets", :key => "admin-password"}}}, {:name => "DATABASE_REGION", :value => "0"}, {:name => "DATABASE_URL", :valueFrom => {:secretKeyRef=>{:name => "manageiq-secrets", :key => "database-url"}}}, {:name => "MY_POD_NAMESPACE", :valueFrom => {:fieldRef=>{:apiVersion => "v1", :fieldPath => "metadata.namespace"}}}, {:name => "V2_KEY", :valueFrom => {:secretKeyRef=>{:name => "manageiq-secrets", :key => "v2-key"}}}], :resources => {}, :volumeMounts => [{:name => "manageiq-server", :mountPath => "/persistent"}, {:name => "miq-orchestrator-token-qlg96", :readOnly => true, :mountPath => "/var/run/secrets/kubernetes.io/serviceaccount"}], :livenessProbe => {:exec => {:command=>["pidof", "MIQ Server"]}, :initialDelaySeconds => 480, :timeoutSeconds => 3, :periodSeconds => 10, :successThreshold => 1, :failureThreshold => 3}, :readinessProbe => {:tcpSocket => {:port=>80}, :initialDelaySeconds => 200, :timeoutSeconds => 3, :periodSeconds => 10, :successThreshold => 1, :failureThreshold => 3}, :lifecycle => {:preStop=>{:exec=>{:command=>["/opt/manageiq/container-scripts/sync-pv-data"]}}}, :terminationMessagePath => "/dev/termination-log", :terminationMessagePolicy => "File", :imagePullPolicy => "IfNotPresent", :securityContext => {:capabilities=>{:drop=>["MKNOD"]}}}], :restartPolicy => "Always", :terminationGracePeriodSeconds => 90, :dnsPolicy => "ClusterFirst", :nodeSelector => {:"node-role.kubernetes.io/compute"=>"true"}, :serviceAccountName => "miq-orchestrator", :serviceAccount => "miq-orchestrator", :nodeName => "dell-r430-20.cloudforms.lab.eng.rdu2.redhat.com", :securityContext => {:seLinuxOptions=>{:level=>"s0:c11,c0"}}, :imagePullSecrets => [{:name=>"miq-orchestrator-dockercfg-9rvgb"}], :hostname => "manageiq-0", :subdomain => "manageiq", :schedulerName => "default-scheduler"}, :status => {:phase => "Running", :conditions => [{:type => "Initialized", :status => "True", :lastProbeTime => nil, :lastTransitionTime => "2018-08-13T20:48:14Z"}, {:type => "Ready", :status => "True", :lastProbeTime => nil, :lastTransitionTime => "2018-08-13T20:51:52Z"}, {:type => "PodScheduled", :status => "True", :lastProbeTime => nil, :lastTransitionTime => "2018-08-13T20:48:14Z"}], :hostIP => "10.8.96.55", :podIP => "10.129.0.77", :startTime => "2018-08-13T20:48:14Z", :containerStatuses => [{:name => "manageiq", :state => {:running=>{:startedAt=>"2018-08-13T20:48:18Z"}}, :lastState => {}, :ready => true, :restartCount => 0, :image => "docker.io/carbonin/manageiq-pods:frontend-latest-hammer", :imageID => "docker-pullable://docker.io/carbonin/manageiq-pods@sha256:78edb45e68d1c6afb5146e2a1809222ff341d4036b4ee8674b8b3e75fc235a10", :containerID => "docker://51bbd66eadbdc713dddb6900f55410395771bda0c64b2a3cf398a4bd8f71d97b"}], :qosClass => "BestEffort"}
      }
    )

    targeted_refresh([notice])
    targeted_refresh_delete_tests("331830bc-9f3a-11e8-ba7e-d094660d31fb")
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
      :service_instance          => 1,
      :service_offering          => 183,
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
      :service_instance          => ServiceInstance.count,
      :service_offering          => ServiceOffering.count,
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

  def assert_specific_service_instance
    @service_instance = ServiceInstance.find_by(:name => "mariadb-persistent-qdkzt")
    expect(@service_instance).to(
      have_attributes(
        :type    => "ManageIQ::Providers::Openshift::ContainerManager::ServiceInstance",
        :name    => "mariadb-persistent-qdkzt",
        :ems_ref => "76af97e3-5650-4583-ae85-27294677f88d",
      )
    )
    expect(@service_instance.extra["spec"]).not_to be_nil
    expect(@service_instance.extra["status"]).not_to be_nil

    # Relation to Project and ems
    # TODO(lsmola) how do we add link to projects?
    # expect(@service_instance.container_project).to eq(ContainerProject.find_by(:name => "default"))
    expect(@service_instance.ext_management_system).to eq(@ems)

    # Relation to ServiceOffering
    expect(@service_instance.service_offering).to(
      have_attributes(
        :type => "ManageIQ::Providers::Openshift::ContainerManager::ServiceOffering",
        :name => "mariadb-persistent"
      )
    )
    expect(@service_instance.service_offering.extra["spec"]).not_to be_nil
    expect(@service_instance.service_offering.extra["status"]).not_to be_nil
    expect(@service_instance.service_offering.service_instances.count).to eq(1)
    expect(@service_instance.service_offering.service_parameters_sets.count).to eq(1)
    expect(@service_instance.service_offering).to(
      eq(@service_instance.service_parameters_set.service_offering)
    )

    # Relation to ServiceParametersSet
    expect(@service_instance.service_parameters_set).to(
      have_attributes(
        :type        => "ManageIQ::Providers::Openshift::ContainerManager::ServiceParametersSet",
        :name        => "default",
        :description => "Default plan",
      )
    )
    expect(@service_instance.service_parameters_set.extra["spec"]).not_to be_nil
    expect(@service_instance.service_parameters_set.extra["status"]).not_to be_nil
    expect(@service_instance.service_parameters_set.service_instances.count).to eq(1)
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

        include_examples "openshift refresher inventory_object VCR tests"
      end
    end
  end
end
