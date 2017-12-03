class ManageIQ::Providers::Openshift::Inventory::Persister::ContainerManager < ManageIQ::Providers::Openshift::Inventory::Persister
  include ManageIQ::Providers::Kubernetes::ContainerManager::InventoryCollections

  def initialize_inventory_collections
    super
    # get_container_images=false mode is a stopgap to speed up refresh by reducing functionality.
    # Skipping these InventoryCollections (instead of returning empty ones)
    # to at least retain existing metadata if it was true and is now false.
    if options.get_container_images
      initialize_custom_attributes_collections(@collections[:container_images], %w(labels docker_labels))
      initialize_taggings_collection(@collections[:container_images])
    end
  end
end
