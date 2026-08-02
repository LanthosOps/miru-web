# frozen_string_literal: true

require "rails_helper"

RSpec.describe InternalDeploymentBootstrapOwner do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")
    allow(ENV).to receive(:[]).with("MIRU_BOOTSTRAP_OWNER_EMAIL").and_return("owner@example.com")
    allow(ENV).to receive(:[]).with("MIRU_BOOTSTRAP_OWNER_PASSWORD").and_return("Password123!")
    allow(ENV).to receive(:[]).with("MIRU_BOOTSTRAP_COMPANY_ID").and_return(nil)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return("owner@example.com")
  end

  it "creates one confirmed owner and remains idempotent" do
    expect { described_class.process }
      .to change(User, :count).by(1)
      .and change(Company, :count).by(1)

    user = User.find_by!(email: "owner@example.com")
    company = user.current_workspace

    expect(user).to be_confirmed
    expect(user.has_role?(:owner, company)).to eq(true)
    expect(user.employed_at?(company.id)).to eq(true)

    expect { described_class.process }
      .to change(User, :count).by(0)
      .and change(Company, :count).by(0)
  end
end
