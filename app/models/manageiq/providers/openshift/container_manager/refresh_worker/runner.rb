class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner < ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker::Runner
  def entity_types
    super + openshift_entity_types
  end

  def openshift_entity_types
    %w[projects routes build_configs builds templates].tap do |types|
      # Only subscribe to Image watches if we're getting and storing OpenShift Images
      types << "images" if refresher_options.get_container_images && !refresher_options.store_unused_images
    end
  end
end
