# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users::Confirmations#create", type: :request do
  let(:user) { create(:user) }

  describe "POST #create" do
    context "when user is not confirmed" do
      before do
        user.update(confirmed_at: nil)
      end

      it "sent confirmation instructions" do
        post api_v1_users_resend_confirmation_email_path({ user: { email: user.email } })
        expect(JSON.parse(response.body)).to include("notice" => "A confirmation email has been sent to #{user.email}.")
      end
    end

    context "when user is already confirmed" do
      before do
        user.confirm
      end

      it "redirects to root_path" do
        post api_v1_users_resend_confirmation_email_path({ user: { email: user.email } })
        expect(JSON.parse(response.body)).to include(
          "notice" => "A confirmation email has been sent to #{user.email}."
        )
      end
    end

    context "when user doesn't exist" do
      it "redirects to root_path" do
        post api_v1_users_resend_confirmation_email_path({ user: { email: "miru@example.com" } })
        expect(JSON.parse(response.body)).to include(
          "notice" => "A confirmation email has been sent to miru@example.com."
        )
      end
    end

    context "with an unapproved internal address" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return("owner@example.com")
        user.update!(confirmed_at: nil)
      end

      it "returns the generic response without issuing confirmation instructions" do
        expect(User).not_to receive(:send_confirmation_instructions)

        post api_v1_users_resend_confirmation_email_path({ user: { email: user.email } })

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          "notice" => "A confirmation email has been sent to #{user.email}."
        )
      end
    end
  end
end
