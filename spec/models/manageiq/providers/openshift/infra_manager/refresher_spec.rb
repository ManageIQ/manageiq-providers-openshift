describe ManageIQ::Providers::Openshift::InfraManager::Refresher do
  context '#refresh' do
    let(:ems) do
      host = VcrSecrets.openshift.hostname
      token = VcrSecrets.openshift.token
      port = VcrSecrets.openshift.port
      zone = EvmSpecHelper.local_miq_server.zone

      FactoryBot.create(:ems_openshift_infra,
                        :name => "openshift Virtualization Manager",
                        :zone => zone).tap do |ems|
        ems.parent_manager.authentications << FactoryBot.create(:authentication, {:authtype => :bearer,
                                                                                  :type     => "AuthToken",
                                                                                  :auth_key => token,
                                                                                  :userid   => "_",
                                                                                  :password => nil})
        ems.parent_manager.default_endpoint.update!(:role              => :default,
                                                    :hostname          => host,
                                                    :port              => port,
                                                    :security_protocol => "ssl-without-validation")
      end
    end

    it 'works correctly with one node' do
      2.times do
        VCR.use_cassette(described_class.name.underscore) do
          EmsRefresh.refresh(ems)
        end

        assert_counts
        assert_specific_flavor
        assert_specific_vm
        assert_specific_host
        assert_specific_cluster
        assert_specific_storage
      end
    end

    def assert_counts
      expect(ems.vms.count).to eq(2)
      expect(ems.hosts.count).to eq(1)
      expect(ems.flavors.count).to eq(44)
      expect(ems.clusters.count).to eq(1)
      expect(ems.storages.count).to eq(1)
    end

    def assert_specific_flavor
      flavor = ems.flavors.find_by(:name => "u1.small")
      expect(flavor).to have_attributes(
        :name            => "u1.small",
        :ems_ref         => "ee6e323e-2c82-4007-a249-adcc2cd43bde",
        :type            => "ManageIQ::Providers::Openshift::InfraManager::Flavor",
        :cpu_total_cores => 1,
        :memory          => 2_048
      )
      expect(flavor.vms).to include(ems.vms.find_by(:name => "centos-stream9-aqua-gull-95"))
    end

    def assert_specific_vm
      vm = ems.vms.find_by(:name => "centos-stream9-aqua-gull-95")
      expect(vm).to have_attributes(
        :ems_ref          => "5f6937bd-e574-42cb-bbd1-3d70ecd3e8e9",
        :name             => "centos-stream9-aqua-gull-95",
        :type             => "ManageIQ::Providers::Openshift::InfraManager::Vm",
        :uid_ems          => "5f6937bd-e574-42cb-bbd1-3d70ecd3e8e9",
        :vendor           => "openshift_infra",
        :power_state      => "on",
        :connection_state => "connected",
        :flavor           => ems.flavors.find_by(:name => "u1.small")
      )

      expect(vm.hardware).to have_attributes(
        :cpu_cores_per_socket => 1,
        :cpu_sockets          => 1,
        :cpu_total_cores      => 1,
        :memory_mb            => 2_048
      )
    end

    def assert_specific_host
      host = ems.hosts.find_by(:ems_ref => "c69d83f1-2133-49ec-8573-f2d28f887116")
      expect(host).to have_attributes(
        :connection_state => "connected",
        :ems_ref          => "c69d83f1-2133-49ec-8573-f2d28f887116",
        :type             => "ManageIQ::Providers::Openshift::InfraManager::Host",
        :uid_ems          => "c69d83f1-2133-49ec-8573-f2d28f887116",
        :vmm_product      => "OpenShift Virtualization",
        :vmm_vendor       => "openshift_infra",
        :vmm_version      => "0.1.0",
        :ems_cluster      => ems.ems_clusters.find_by(:ems_ref => "0")
      )
      expect(host.hardware).to have_attributes(
        :cpu_total_cores => 12,
        :memory_mb       => 19_997
      )
    end

    def assert_specific_cluster
      cluster = ems.ems_clusters.find_by(:ems_ref => "0")
      expect(cluster).to have_attributes(
        :ems_ref => "0",
        :name    => "openshift Virtualization Manager",
        :uid_ems => "0",
        :type    => "ManageIQ::Providers::Openshift::InfraManager::Cluster"
      )
    end

    def assert_specific_storage
      storage = ems.storages.find_by(:ems_ref => "0")
      expect(storage).to have_attributes(
        :name        => "openshift Virtualization Manager",
        :total_space => 0,
        :free_space  => 0,
        :ems_ref     => "0",
        :type        => "ManageIQ::Providers::Openshift::InfraManager::Storage"
      )
    end
  end
end
