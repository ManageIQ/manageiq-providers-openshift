class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner < ManageIQ::Providers::BaseManager::RefreshWorker::Runner
  include ManageIQ::Providers::Kubernetes::ContainerManager::StreamingRefreshMixin

  def connection_for_entity(entity_type)
    kubernetes_entity_types.include?(entity_type) ? kubernetes_connection : openshift_connection
  end

  def openshift_connection
    @openshift_connection ||= ems.connect
  end

  def openshift_entity_types
    %w(
      templates
    )
  end

  def entity_types
    kubernetes_entity_types + openshift_entity_types
  end
end
