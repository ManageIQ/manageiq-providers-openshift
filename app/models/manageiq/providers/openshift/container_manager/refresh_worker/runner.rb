class ManageIQ::Providers::Openshift::ContainerManager::RefreshWorker::Runner < ManageIQ::Providers::BaseManager::RefreshWorker::Runner
  include ManageIQ::Providers::Kubernetes::ContainerManager::StreamingRefreshMixin

  def start_watches
    watch_streams = super

    openshift_connection = ems.connect
    openshift_entities.each do |entity|
      watch_streams[entity] = start_watch(openshift_connection, entity)
    end

    watch_streams
  end

  def openshift_entities
    %w(
      templates
      images
    )
  end
end
