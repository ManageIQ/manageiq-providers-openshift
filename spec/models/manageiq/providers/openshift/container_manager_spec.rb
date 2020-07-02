describe ManageIQ::Providers::Openshift::ContainerManager do
  it "#catalog_types" do
    ems = FactoryBot.create(:ems_openshift)
    expect(ems.catalog_types).to include("generic_container_template")
  end

  describe "#v3?" do
    context "with a v3 cluster" do
      let(:ems) { FactoryBot.create(:ems_openshift, :api_version => "3.11.0") }

      it "returns true" do
        expect(ems.v3?).to be_truthy
      end
    end

    context "with a v4 cluster" do
      let(:ems) { FactoryBot.create(:ems_openshift, :api_version => "4.3.0") }

      it "returns false" do
        expect(ems.v3?).to be_falsey
      end
    end
  end

  describe "#v4?" do
    context "with a v3 cluster" do
      let(:ems) { FactoryBot.create(:ems_openshift, :api_version => "3.11.0") }

      it "returns false" do
        expect(ems.v4?).to be_falsey
      end
    end

    context "with a v4 cluster" do
      let(:ems) { FactoryBot.create(:ems_openshift, :api_version => "4.3.0") }

      it "returns true" do
        expect(ems.v4?).to be_truthy
      end
    end
  end
end
