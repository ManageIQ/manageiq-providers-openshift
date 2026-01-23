class ManageIQ::Providers::Openshift::Inventory::Persister::InfraManager < ManageIQ::Providers::Kubevirt::Inventory::Persister
  def template_collection(targeted: false, ids: [])
    add_collection(infra, :miq_templates) do |builder|
      builder.add_properties(
        :targeted                     => targeted,
        :manager_uuids                => ids,
        :parent_inventory_collections => %i(vms)
      )

      builder.add_default_values(
        :type   => "#{manager.class}::Template",
        :vendor => manager.class.vendor
      )
    end
  end
end
