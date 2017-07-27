class ManageIQ::Providers::Openshift::ContainerManager::ContainerImage < ContainerImage
  def annotate_image(annotations)
    # TODO: support sti and replace check with inplementing only for OpenShift providers
    unless ext_management_system.kind_of?(ManageIQ::Providers::Openshift::ContainerManagerMixin)
      _log.error("#{__method__} only applicable for OpenShift Providers")
      return
    end
    ext_management_system.annotate(
      "image",
      digest,
      annotations
    )
  end

  def openscap_summary
    failed_rules = openscap_rule_results.where(:result => "fail").group(:severity).count
    [[['High'], 'Critical', 3],
     [['Medium'], 'Important', 2],
     [['Low'], 'Medium', 1],
     [['Info', 'Unknown'], 'Low', 0]].collect do |severities, label, index|
      {
        :label         => label,
        :severityIndex => index,
        :data          => failed_rules.select { |sev| severities.include?(sev) }.values.sum
      }
    end
  end

  def security_quality_annotation(compliant)
    {"quality.images.openshift.io/vulnerability.manageiq" => {
      :name        => "ManageIQ",
      :timestamp   => Time.now.utc.to_i,
      :description => "OpenSCAP Score",
      :reference   => "",
      :compliant   => compliant,
      :summary     => openscap_summary
    }.to_json}
  end

  def annotate_allow_execution(causing_policy)
    annotate_image({
      "security.manageiq.org/successful-policy" => causing_policy,
      "images.openshift.io/allow-execution"     => "true"
    }.merge!(security_quality_annotation(true)))
  end

  def annotate_deny_execution(causing_policy)
    annotate_image({
      "security.manageiq.org/failed-policy" => causing_policy,
      "images.openshift.io/deny-execution"  => "true"
    }.merge!(security_quality_annotation(false)))
  end
end
