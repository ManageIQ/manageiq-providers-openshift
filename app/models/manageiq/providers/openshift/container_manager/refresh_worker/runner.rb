class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner < ManageIQ::Providers::BaseManager::RefreshWorker::Runner
  include ManageIQ::Providers::Kubernetes::ContainerManager::StreamingRefreshMixin

  def connection_for_entity(entity_type)
    super || openshift_connection
  end

  def openshift_connection
    @openshift_connection ||= connect("openshift")
  end

  def openshift_entity_types
    %w(
      templates
    )
  end

  def entity_types
    super + openshift_entity_types
  end
end
