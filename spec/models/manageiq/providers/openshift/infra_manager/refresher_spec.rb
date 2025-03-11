describe ManageIQ::Providers::Openshift::InfraManager::Refresher do
  context '#refresh' do
    let(:ems) do
      host = Rails.application.secrets.openshift[:hostname]
      token = Rails.application.secrets.openshift[:token]
      port = Rails.application.secrets.openshift[:port]
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
        assert_specific_vm
        assert_specific_host
        assert_specific_cluster
        assert_specific_storage
      end
    end

    def assert_counts
      expect(ems.vms.count).to eq(1)
      expect(ems.hosts.count).to eq(1)
      expect(ems.clusters.count).to eq(1)
      expect(ems.storages.count).to eq(1)
    end

    def assert_specific_vm
      vm = ems.vms.find_by(:name => "centos-stream9-lavender-manatee-97")
      expect(vm).to have_attributes(
        :ems_ref          => "fb22c624-ae4c-4e1e-8fd9-7e7a7aadde76",
        :name             => "centos-stream9-lavender-manatee-97",
        :type             => "ManageIQ::Providers::Openshift::InfraManager::Vm",
        :uid_ems          => "fb22c624-ae4c-4e1e-8fd9-7e7a7aadde76",
        :vendor           => "openshift_infra",
        :power_state      => "on",
        :connection_state => "connected"
      )
    end

    def assert_specific_host
      host = ems.hosts.find_by(:ems_ref => "436c15c9-86cf-4fd6-9290-d219d2a59221")
      expect(host).to have_attributes(
        :connection_state => "connected",
        :ems_ref          => "436c15c9-86cf-4fd6-9290-d219d2a59221",
        :type             => "ManageIQ::Providers::Openshift::InfraManager::Host",
        :uid_ems          => "436c15c9-86cf-4fd6-9290-d219d2a59221",
        :vmm_product      => "OpenShift Virtualization",
        :vmm_vendor       => "openshift_infra",
        :vmm_version      => "0.1.0",
        :ems_cluster      => ems.ems_clusters.find_by(:ems_ref => "0")
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
