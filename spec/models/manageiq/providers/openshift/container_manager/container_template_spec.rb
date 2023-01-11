describe ContainerTemplate do
  let(:ems) do
    # env vars for easier VCR recording, see test_objects_record.sh
    hostname = Rails.application.secrets.openshift[:hostname]
    token = Rails.application.secrets.openshift[:token]
    port = Rails.application.secrets.openshift[:port]

    FactoryBot.create(
      :ems_openshift_with_zone,
      :name                      => "OpenShiftProvider",
      :connection_configurations => [{:endpoint       => {:role              => :default,
                                                          :hostname          => hostname,
                                                          :port              => port,
                                                          :security_protocol => "ssl-without-validation"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}},
                                     {:endpoint       => {:role     => :prometheus,
                                                          :hostname => hostname,
                                                          :port     => 443},
                                      :authentication => {:role     => :prometheus,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )
  end

  it "instantiate a template with parameters and object labels" do
    param = FactoryBot.create(:container_template_parameter,
                              :name     => 'VAR',
                              :value    => 'example',
                              :required => true)

    object = {:apiVersion => "v1",
              :kind       => "PersistentVolumeClaim",
              :metadata   => {:name => "pvc-${VAR}"},
              :spec       => {:accessModes => ["ReadWriteOnce"],
                              :resources   => {:requests => {:storage => "8Gi"}}}}

    object_labels = {:created_from_template => "true"}

    template = FactoryBot.create(:openshift_template,
                                 :ems_id        => ems.id,
                                 :objects       => [object],
                                 :object_labels => object_labels).tap do |temp|
      temp.container_template_parameters = [param]
    end

    VCR.use_cassette(described_class.name.underscore,
                     :match_requests_on              => [:path, :body],
                     :allow_unused_http_interactions => false) do # , :record => :new_episodes) do
      ems.create_project(:metadata => {:name => "test-project"})
      objects = template.instantiate(template.container_template_parameters, "test-project", template.object_labels)

      pvc = objects.first
      expect(pvc[:kind]).to eq("PersistentVolumeClaim")
      expect(pvc[:miq_class]).to eq(PersistentVolumeClaim)
      expect(pvc[:metadata][:name]).to eq("pvc-example")
      expect(pvc[:metadata][:labels]).to eq(:created_from_template => "true")
    end
  end
end
