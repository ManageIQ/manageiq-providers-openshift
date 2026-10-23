class ManageIQ::Providers::Openshift::InfraManager::EventCatcher::Runner < ManageIQ::Providers::Kubevirt::InfraManager::EventCatcher::Runner
  private

  def worker_cmdline
    ManageIQ::Providers::Kubevirt::Engine.root.join("workers/manageiq/providers/kubevirt/infra_manager/event_catcher/worker").to_s
  end
end
