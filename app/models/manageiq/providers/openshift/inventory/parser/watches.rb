class ManageIQ::Providers::Openshift::Inventory::Parser::Watches < ManageIQ::Providers::Kubernetes::Inventory::Parser::Watches
  def parse
    super

    parse_template_notices(collector.template_notices)
  end

  private

  def parse_template_notices(template_notices)
    template_notices.each do |notice|
      template = notice.object
      template_inv_obj = parse_template(template)
      assign_deleted_on(template_inv_obj, template) if notice.type == "DELETED"
    end
  end
end
