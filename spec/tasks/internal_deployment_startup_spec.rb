# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "internal_deployment:startup" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none?
  end

  let(:task) { Rake::Task["internal_deployment:startup"] }

  before do
    task.reenable
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
  end

  it "leaves standard deployments unchanged" do
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("false")

    expect(InternalDeploymentBootstrapOwner).not_to receive(:process)
    expect(InternalDeploymentPreflight).not_to receive(:verify!)

    task.invoke
  end

  it "uses Rails Boolean parsing and bootstraps before verifying" do
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("True")
    allow(ENV).to receive(:[]).with("MIRU_BOOTSTRAP_OWNER_PASSWORD").and_return("Password123!")
    allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return("owner@example.com")

    expect(InternalDeploymentBootstrapOwner).to receive(:process).ordered
    expect(InternalDeploymentPreflight).to receive(:verify!).ordered

    task.invoke
  end
end
