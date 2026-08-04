# frozen_string_literal: true

require "rails_helper"

RSpec.describe InternalDeploymentPreflight do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return("owner@example.com")
  end

  it "passes only when an approved owner exists and cutover state is clean" do
    company = create(:company)
    owner = create(:user, email: "owner@example.com", current_workspace_id: company.id)
    create(:employment, company:, user: owner)
    owner.add_role(:owner, company)

    expect(described_class.verify!).to eq(true)
  end

  it "rejects any remaining Stripe customer identifier" do
    company = create(:company, stripe_customer_id: "cus_live")
    owner = create(:user, email: "owner@example.com", current_workspace_id: company.id)
    create(:employment, company:, user: owner)
    owner.add_role(:owner, company)

    expect { described_class.verify! }
      .to raise_error(described_class::UnsafeConfiguration, /Billing identifiers/)
  end

  it "rejects pending invitations outside the allowlist" do
    company = create(:company)
    owner = create(:user, email: "owner@example.com", current_workspace_id: company.id)
    create(:employment, company:, user: owner)
    owner.add_role(:owner, company)
    create(:invitation, company:, recipient_email: "employee@example.com")

    expect { described_class.verify! }
      .to raise_error(described_class::UnsafeConfiguration, /Pending invitations/)
  end

  it "rejects unaccepted legacy Devise invitations outside the allowlist" do
    company = create(:company)
    owner = create(:user, email: "owner@example.com", current_workspace_id: company.id)
    create(:employment, company:, user: owner)
    owner.add_role(:owner, company)
    create(:user, email: "employee@example.com").update_columns(
      invitation_token: "legacy-token",
      invitation_sent_at: Time.current,
      invitation_accepted_at: nil
    )

    expect { described_class.verify! }
      .to raise_error(described_class::UnsafeConfiguration, /Legacy Devise invitations/)
  end

  it "rejects a deployment without an approved company owner" do
    create(:company)

    expect { described_class.verify! }
      .to raise_error(described_class::UnsafeConfiguration, /bootstrap_owner/)
  end

  it "rejects an approved owner whose employment was disabled" do
    company = create(:company)
    owner = create(:user, email: "owner@example.com", current_workspace_id: company.id)
    employment = create(:employment, company:, user: owner)
    owner.add_role(:owner, company)
    employment.discard!

    expect { described_class.verify! }
      .to raise_error(described_class::UnsafeConfiguration, /bootstrap_owner/)
  end
end
