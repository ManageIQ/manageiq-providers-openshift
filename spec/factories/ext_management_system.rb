FactoryBot.define do
  factory :ems_openshift_with_zone, :parent => :ems_openshift do
    zone do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      zone
    end
  end

  factory :ems_openshift_infra,
          :aliases => ["manageiq/providers/openshift/infra_manager"],
          :class   => "ManageIQ::Providers::Openshift::InfraManager",
          :parent  => :ems_kubevirt do
    parent_manager { FactoryBot.create(:ems_openshift) }
  end
end
