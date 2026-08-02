# frozen_string_literal: true

require "rails_helper"

RSpec.describe Devise::Mailer, type: :mailer do
  context "with internal deployment branding" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("REPLY_TO_EMAIL", "support@datapulsetech.ai").and_return("ops@datapulsetech.ai")
    end

    it "uses Lanthos copy across account lifecycle emails" do
      user = create(:user)
      mailer_class = Devise.mailer
      messages = [
        mailer_class.confirmation_instructions(user, "confirmation-token"),
        mailer_class.reset_password_instructions(user, "reset-token"),
        mailer_class.email_changed(user),
        mailer_class.password_change(user),
        mailer_class.unlock_instructions(user, "unlock-token")
      ]

      messages.each do |message|
        expect(message.subject).to include("Lanthos Ops")
        expect(message.subject).not_to include("Miru")
        expect(message.body.encoded).to include("Lanthos Ops")
        expect(message.body.encoded).not_to include("hello@saeloun.com")
      end
    end
  end

  describe "email_changed" do
    it "includes the support alias in the body" do
      user = create(:user)

      mail = described_class.email_changed(user)

      expect(mail.body.encoded).to include("hello@saeloun.com")
    end
  end

  describe "password_change" do
    it "includes the support alias in the body" do
      user = create(:user)

      mail = described_class.password_change(user)

      expect(mail.body.encoded).to include("hello@saeloun.com")
    end
  end

  describe "unlock_instructions" do
    it "explains the timed lock behavior and points to sign in" do
      user = create(:user)

      mail = described_class.unlock_instructions(user, "preview-unlock-token")

      expect(mail.body.encoded).to include("30 minutes")
      expect(mail.body.encoded).to include("/password/new")
      expect(mail.body.encoded).to include("secure once the lock expires")
    end
  end
end
