class ManageIQ::Providers::Openshift::Inventory::Parser::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Parser::ContainerManager
  def parse
    super

    parse_templates(collector.templates)
  end

  private

  def parse_templates(templates)
    templates.each { |template| parse_template(template) }
  end

  def parse_template(template)
    persister_template = persister.container_templates.build(
      parse_base_item(template).merge(
        :type              => "ManageIQ::Providers::Openshift::ContainerManager::ContainerTemplate",
        :objects           => template.objects.to_a.collect(&:to_h),
        :object_labels     => template.labels.to_h,
        :container_project => lazy_find_project(template),
      )
    )

    parse_template_parameters(persister_template, template.parameters)
  end

  def parse_template_parameters(persister_template, parameters)
    parameters.to_a.each do |param|
      persister.container_template_parameters.build(
        {
          :container_template => persister_template,
          :name               => param['name'],
          :display_name       => param['displayName'],
          :description        => param['description'],
          :value              => param['value'],
          :generate           => param['generate'],
          :from               => param['from'],
          :required           => param['required']
        }
      )
    end
  end
end
