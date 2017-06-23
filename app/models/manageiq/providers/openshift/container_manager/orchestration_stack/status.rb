class ManageIQ::Providers::Openshift::ContainerManager::OrchestrationStack::Status < ::OrchestrationStack::Status
  def succeeded?
    status.downcase == "completed"
  end

  def failed?
    status.downcase =~ /failed$/
  end
end
