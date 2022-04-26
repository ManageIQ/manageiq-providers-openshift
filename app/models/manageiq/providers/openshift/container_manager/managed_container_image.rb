class ManageIQ::Providers::Openshift::ContainerManager::ManagedContainerImage < ManageIQ::Providers::Openshift::ContainerManager::ContainerImage
  supports :capture

  def annotate_image(annotations)
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
    {"quality.images.openshift.io/vulnerability.openscap" => {
      :name        => "ManageIQ",
      :timestamp   => Time.now.utc.to_i,
      :description => "OpenSCAP Score",
      :reference   => "",
      :compliant   => compliant,
      :summary     => openscap_summary
    }.to_json}
  end

  def annotate_scan_policy_results(causing_policy, compliant)
    annotate_image({
      "security.manageiq.org/#{compliant ? "successful" : "failed"}-policy" => causing_policy,
      "images.openshift.io/deny-execution"  => (!compliant).to_s
    }.merge!(security_quality_annotation(compliant)))
  end
end
