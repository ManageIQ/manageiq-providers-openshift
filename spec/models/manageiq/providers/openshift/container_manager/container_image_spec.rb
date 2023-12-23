describe ManageIQ::Providers::Openshift::ContainerManager::ContainerImage do
  context "#security_quality_annotation" do
    let(:container_image)      { FactoryBot.create(:openshift_managed_container_image) }
    let(:blob)                 { FactoryBot.create(:binary_blob, :binary => "blah", :name => "test_blob") }
    let(:scan_result) do
      FactoryBot.create(:openscap_result_skip_callback,
                        :binary_blob        => blob,
                        :resource_id        => container_image.id,
                        :resource_type      => container_image.type,
                        :container_image_id => container_image.id)
    end
    let(:successful_rule) do
      FactoryBot.create(:openscap_rule_result,
                        :openscap_result_id => scan_result.id,
                        :severity           => "High",
                        :result             => "success")
    end
    let(:failed_rule) do
      FactoryBot.create(:openscap_rule_result,
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
        container_image.openscap_result.openscap_rule_results << FactoryBot.create(
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
