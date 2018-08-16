class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner < ManageIQ::Providers::BaseManager::RefreshWorker::Runner
  include ManageIQ::Providers::Kubernetes::ContainerManager::StreamingRefreshMixin

  def save_resource_versions(inventory)
    super

    openshift_entity_types.each do |entity_type|
      resource_versions[entity_type] = inventory.collector.send(entity_type).resourceVersion
    end
  end

  def start_watches
    watch_streams = super

    openshift_connection = ems.connect
    openshift_entity_types.each do |entity_type|
      watch_streams[entity_type] = start_watch(openshift_connection, entity_type, resource_versions[entity_type])
    end

    watch_streams
  end

  def openshift_entity_types
    %w(
      templates
    )
  end
end
