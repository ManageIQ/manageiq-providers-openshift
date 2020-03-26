class ManageIQ::Providers::Openshift::Inventory::Persister::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Persister::ContainerManager
  def initialize_inventory_collections
    super

    # get_container_images=false mode is a stopgap to speed up refresh by reducing functionality.
    # Skipping these InventoryCollections (instead of returning empty ones)
    # to at least retain existing metadata if it was true and is now false.
    if options.get_container_images
      add_custom_attributes(:container_images, %w(labels docker_labels))
    end
  end
end
