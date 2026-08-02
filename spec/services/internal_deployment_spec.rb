# frozen_string_literal: true

require "rails_helper"

RSpec.describe InternalDeployment do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
  end

  it "keeps upstream signup open when internal mode and the allowlist are both unset" do
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return(nil)
    allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return("")

    expect(described_class.signup_email_allowed?("anyone@example.com")).to eq(true)
  end

  it "keeps upstream signup open when internal mode is off and an allowlist remains configured" do
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("false")
    allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return("owner@example.com")

    expect(described_class.signup_email_allowed?("anyone@example.com")).to eq(true)
  end

  it "fails closed when internal mode has no allowlist" do
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")
    allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return("")

    expect(described_class.signup_email_allowed?("owner@example.com")).to eq(false)
  end

  it "matches approved internal users case-insensitively" do
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")
    allow(ENV).to receive(:fetch)
      .with("MIRU_ALLOWED_SIGNUP_EMAILS", "")
      .and_return("Owner@Example.com, second@example.com")

    expect(described_class.signup_email_allowed?(" owner@example.com ")).to eq(true)
    expect(described_class.signup_email_allowed?("other@example.com")).to eq(false)
  end
end
