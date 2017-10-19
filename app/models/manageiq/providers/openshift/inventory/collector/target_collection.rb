class ManageIQ::Providers::Openshift::Inventory::Collector::TargetCollection < ManageIQ::Providers::Openshift::Inventory::Collector
  include ManageIQ::Providers::Kubernetes::ContainerManager::TargetCollectionMixin

  def inventory(entities)
    full_inventory = clean_inventory(entities)

    # Fill pods from Targets
    full_inventory['pod'] = pods
    # Fill pods references
    full_inventory.merge!(pods_references(pods))

    # TODO(lsmola) I am collecting just namespaces, there are OSE projects, but return [], should it work?
    full_inventory
  end
end
