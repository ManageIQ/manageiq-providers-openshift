module ManageIQ::Providers
  class Openshift::ContainerManager::MetricsCollectorWorker < BaseManager::MetricsCollectorWorker
    require_nested :Runner

    self.default_queue_name = "openshift"

    def friendly_name
      @friendly_name ||= "C&U Metrics Collector for OpenShift"
    end
  end
end
