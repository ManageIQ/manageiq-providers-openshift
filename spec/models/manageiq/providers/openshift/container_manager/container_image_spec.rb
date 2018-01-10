describe ManageIQ::Providers::Openshift::ContainerManager::ContainerImage do
  context "#security_quality_annotation" do
    let(:openshift_image_type) { "ManageIQ::Providers::Openshift::ContainerManager::ContainerImage" }
    let(:container_image) do
      FactoryGirl.create(:openshift_container_image,
                         :type => openshift_image_type)
    end
    let(:blob) do
      FactoryGirl.create(:binary_blob,
                         :binary => "blah",
                         :name   => "test_blob")
    end
    let(:scan_result) do
      FactoryGirl.create(:openscap_result_skip_callback,
                         :binary_blob        => blob,
                         :resource_id        => container_image.id,
                         :resource_type      => openshift_image_type,
                         :container_image_id => container_image.id)
    end
    let(:successful_rule) do
      FactoryGirl.create(:openscap_rule_result,
                         :openscap_result_id => scan_result.id,
                         :severity           => "High",
                         :result             => "success")
    end
    let(:failed_rule) do
      FactoryGirl.create(:openscap_rule_result,
                         :openscap_result_id => scan_result.id,
                         :severity           => "Medium",
                         :result             => "fail")
    end

    before :each do
      container_image.update(:openscap_result => scan_result)
      container_image.openscap_result.openscap_rule_results << successful_rule
      container_image.openscap_result.openscap_rule_results << failed_rule
    end

    def assert_severities_data_score(scores)
      summary = %w(Critical Important Medium Low).collect.with_index do |sev, ind|
        {:label => sev, :severityIndex => 3 - ind, :data => scores[sev] || 0 }
      end
      expect(container_image.security_quality_annotation(true)[
        "quality.images.openshift.io/vulnerability.openscap"])
        .to include({
          :summary => summary
        }.to_json[1..-1])
    end

    it "will annotate only the failed rules" do
      assert_severities_data_score("Important" => 1)
    end

    it "will merge the Info and Unknown severities" do
      %w(Info Unknown).each do |sev|
        container_image.openscap_result.openscap_rule_results << FactoryGirl.create(
          :openscap_rule_result,
          :openscap_result_id => scan_result.id,
          :severity           => sev,
          :result             => "fail"
        )
      end
      assert_severities_data_score("Important" => 1, "Low" => 2)
    end
  end
end
