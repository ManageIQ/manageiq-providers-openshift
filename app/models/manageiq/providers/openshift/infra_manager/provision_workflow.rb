class ManageIQ::Providers::Openshift::InfraManager::ProvisionWorkflow < ManageIQ::Providers::Kubevirt::InfraManager::ProvisionWorkflow
  def self.provider_model
    ManageIQ::Providers::Openshift::InfraManager
  end

  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'openshift'})
  end
end
