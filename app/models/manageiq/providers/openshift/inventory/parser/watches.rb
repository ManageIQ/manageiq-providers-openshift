class ManageIQ::Providers::Openshift::Inventory::Parser::Watches < ManageIQ::Providers::Kubernetes::Inventory::Parser::Watches
  def parse
    super

    parse_images(collector.notices["Image"])
    parse_templates(collector.notices["Template"])
  end

  private

  def parse_images(image_notices)
  end

  def parse_templates(template_notices)
    template_notices.each do |template_notice|
      persister.container_templates.targeted_scope << template_notice.object.metadata.uid
      next if template_notice.action == "DELETE"

      template = template_notice.object
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
end
