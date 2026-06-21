module ManageIQ::Providers::Openshift::Inventory::Parser::InfraManager::ParserMixin
  extend ActiveSupport::Concern

  attr_reader :template_collection

  def process_templates(objects)
    objects.each do |object|
      process_template(object)
    end
  end

  def process_template(object)
    # Get the basic information:
    uid = object.metadata.uid
    vm  = vm_from_objects(object.objects)
    return if vm.nil?

    # Add the inventory object for the template:
    template_object = template_collection.find_or_build(uid)
    template_object.connection_state = 'connected'
    template_object.ems_ref = uid
    template_object.name = object.metadata.name
    template_object.raw_power_state = 'never'
    template_object.template = true
    template_object.uid_ems = uid
    template_object.location = object.metadata.namespace

    # Add the inventory object for the hardware:
    process_hardware(template_object, object.parameters, object.metadata.labels, vm.dig(:spec, :template, :spec, :domain))

    # Add the inventory object for the OperatingSystem
    process_os(template_object, object.metadata.labels, object.metadata.annotations)
  end
end
