ManageIQ::Providers::Kubernetes::ContainerManager::ContainerImage.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Openshift::ContainerManager::ContainerImage < ManageIQ::Providers::Kubernetes::ContainerManager::ContainerImage
  supports_not :capture

  def self.disconnect_inv(ids)
    _log.info "Disconnecting Images [#{ids}]"
    base_class.where(:id => ids).update_all(:container_image_registry_id => nil, :deleted_on => Time.now.utc)
  end
end
