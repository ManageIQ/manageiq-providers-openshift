class ManageIQ::Providers::Openshift::InfraManager::MetricsCollectorWorker < ManageIQ::Providers::BaseManager::MetricsCollectorWorker
  self.default_queue_name = "openshift_infra"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for OpenShift Virtualization"
  end

  # Override PerEmsTypeWorkerMixin.all_valid_ems_in_zone to limit metrics collection
  def self.all_ems_in_zone
    super.select do |ems|
      ems.supports?(:metrics).tap do |supported|
        _log.info("Skipping [#{ems.name}] since it has no metrics endpoint") unless supported
      end
    end
  end
end
