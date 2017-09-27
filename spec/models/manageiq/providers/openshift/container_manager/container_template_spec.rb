describe ContainerTemplate do
  let(:ems) do
    hostname = 'host.example.com'
    token = 'theToken'
    FactoryGirl.create(
      :ems_openshift,
      :name                      => 'OpenShiftProvider',
      :connection_configurations => [{:endpoint       => {:role     => :default,
                                                          :hostname => hostname,
                                                          :port     => "8443"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}},
                                     {:endpoint       => {:role     => :hawkular,
                                                          :hostname => hostname,
                                                          :port     => "443"},
                                      :authentication => {:role     => :hawkular,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )
  end

  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
  end

  it "instantiate a template with parameters and object labels" do
    param = FactoryGirl.create(:container_template_parameter,
                               :name     => 'VAR',
                               :value    => 'example',
                               :required => true)

    object = {:apiVersion => "v1",
              :kind       => "PersistentVolumeClaim",
              :metadata   => {:name => "pvc-${VAR}"},
              :spec       => {:accessModes => ["ReadWriteOnce"],
                              :resources   => {:requests => {:storage => "8Gi"}}}}

    object_labels = {:created_from_template => "true"}

    template = FactoryGirl.create(:openshift_template,
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
