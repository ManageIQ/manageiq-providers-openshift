autoload(:KubeException, 'kubeclient')

class ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate < ManageIQ::Providers::ContainerManager::ContainerTemplate
  include ManageIQ::Providers::Kubernetes::ContainerManager::EntitiesMapping

  def instantiate_supported?
    true
  end

  def instantiate_unsupported_reason
    nil
  end

  supports :instantiate do
    unsupported_reason_add(:instantiate, instantiate_unsupported_reason) unless instantiate_supported?
  end

  def instantiate(params, project = nil, labels = nil)
    project ||= container_project.name
    labels  ||= object_labels
    processed_template = process_template(ext_management_system.connect(:api_group => "template.openshift.io"),
                                          :metadata   => {
                                            :name      => name,
                                            :namespace => project
                                          },
                                          :objects    => objects,
                                          :parameters => params.collect(&:instantiation_attributes),
                                          :labels     => labels)
    create_objects(processed_template['objects'], project)
    @created_objects.each { |obj| obj[:miq_class] = model_by_entity(obj[:kind].underscore) }
  end

  def process_template(client, template)
    client.process_template(template)
  rescue KubeException => e
    raise MiqException::MiqProvisionError, "Unexpected Exception while processing template: #{e}"
  end

  def create_objects(objects, project)
    @created_objects = []
    objects.each { |obj| @created_objects << create_object(obj, project).to_h }
  end

  def create_object(obj, project)
    obj = obj.deep_symbolize_keys
    obj[:metadata][:namespace] = project
    method_name = "create_#{obj[:kind].underscore}"
    begin
      client = ext_management_system.connect_client(obj[:kind], obj[:apiVersion], method_name)
      client.send(method_name, obj)
    rescue KubeException => e
      rollback_objects(@created_objects)
      raise MiqException::MiqProvisionError, "Unexpected Exception while creating object: #{e}"
    end
  end

  # rollback_objects cannot catch children objects created during the template instantiation and therefore those objects
  # will remain in the cluster.
  def rollback_objects(objects)
    objects.each { |obj| rollback_object(obj) }
  end

  def rollback_object(obj)
    method_name = "delete_#{obj[:kind].underscore}"
    begin
      client = ext_management_system.connect_client(obj[:kind], obj[:apiVersion], method_name)
      client.send(method_name, obj[:metadata][:name], obj[:metadata][:namespace])
    rescue KubeException => e
      _log.error("Unexpected Exception while deleting object: #{e}")
    end
  end

  def self.display_name(number = 1)
    n_('Container Template (OpenShift)', 'Container Templates (OpenShift)', number)
  end
end
