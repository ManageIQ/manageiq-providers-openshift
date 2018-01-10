describe ManageIQ::Providers::Openshift::ContainerManager do
  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    hostname = 'host.example.com'
    token = 'theToken'

    @ems = FactoryGirl.create(
      :ems_openshift,
      :name                      => 'OpenShiftProvider',
      :connection_configurations => [{:endpoint       => {:role       => :default,
                                                          :hostname   => hostname,
                                                          :port       => "8443",
                                                          :verify_ssl => OpenSSL::SSL::VERIFY_NONE},
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

  it 'creates a new project' do
    VCR.use_cassette(described_class.name.underscore + "/projects",
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true, :record => :new_episodes) do
      project_request = Kubeclient::Resource.new
      project_request[:apiVersion] = 'v1'
      project_request[:kind] = 'ProjectRequest'
      project_request[:metadata] = {}
      project_request[:metadata][:name] = 'projectrequest'
      project_response = @ems.create_project(project_request)

      expect(project_response[:kind]).to eq('Project')
      expect(project_response[:metadata][:name]).to eq('projectrequest')
    end
  end

  it 'deletes an existing project' do
    VCR.use_cassette(described_class.name.underscore + "/projects",
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true, :record => :new_episodes) do
      deleted_project = @ems.delete_project('projectrequest')
      expect(deleted_project.code).to eq(200)
    end
  end

  it 'retrieves the list of users in the provider' do
    VCR.use_cassette(described_class.name.underscore + "/users",
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true, :record => :new_episodes) do
      users = @ems.users_from_provider
      expect(users.kind_of?(Kubeclient::Common::EntityList)).to be_truthy
    end
  end

  it 'retrieves a user from the provider by name' do
    VCR.use_cassette(described_class.name.underscore + "/users",
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true, :record => :new_episodes) do
      user = @ems.user_from_provider("kevensen")
      expect(user[:metadata][:name]).to eq("kevensen")
      expect(@ems.user_exists_in_provider?("kevensen")).to be_truthy
    end
  end
end
