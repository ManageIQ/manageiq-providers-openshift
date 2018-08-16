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
    persister.container_templates.build(
      :ems_ref          => template.metadata.uid,
      :name             => template.metadata.name,
      :namespace        => template.metadata.namespace,
      :ems_created_on   => template.metadata.creationTimestamp,
      :resource_version => template.metadata.resourceVersion,
      :objects          => template.objects.to_a.collect(&:to_h),
      :object_labels    => template.labels.to_h,
    )
  end
end
