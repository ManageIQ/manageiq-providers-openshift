class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner < ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker::Runner
  def entity_types
    super + openshift_entity_types
  end

  def openshift_entity_types
    %w[projects routes build_configs builds templates]
  end
end
