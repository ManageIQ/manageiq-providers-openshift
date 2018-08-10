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
  end
end
