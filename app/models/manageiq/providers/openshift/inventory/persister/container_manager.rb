class ManageIQ::Providers::Openshift::Inventory::Persister::ContainerManager < ManageIQ::Providers::Openshift::Inventory::Persister
  include ManageIQ::Providers::Kubernetes::ContainerManager::InventoryCollections

  def initialize_inventory_collections
    super
    # get_container_images=false mode is a stopgap to speed up refresh by reducing functionality.  When it's flipped from true to false, we should at least retain existing metadata.
    if options.get_container_images
      initialize_custom_attributes_collections(manager.container_images, %w(labels docker_labels))
    end
  end
end
