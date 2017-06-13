class ManageIQ::Providers::Openshift::ContainerManager::ContainerImage < ContainerImage
  def annotate_deny_execution(causing_policy)
    ext_management_system.annotate(
      "image",
      digest,
      "security.manageiq.org/failed-policy" => causing_policy,
      "images.openshift.io/deny-execution"  => "true"
    )
  end
end
