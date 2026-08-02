# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users::Passwords#create", type: :request do
  let(:user) { create(:user) }

  describe "POST #create" do
    context "with valid email" do
      it "sends password reset instructions" do
        send_request :post, api_v1_users_forgot_password_path, params: { user: { email: user.email } }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          "notice" => I18n.t("password.create.success")
        )
      end

      it "does not issue a reset token to a disallowed internal account" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return("owner@example.com")

        send_request :post, api_v1_users_forgot_password_path, params: { user: { email: user.email } }

        expect(response).to have_http_status(:ok)
        expect(user.reload.reset_password_token).to be_nil
        expect(user.reset_password_sent_at).to be_nil
      end
    end

    context "with invalid email" do
      it "responds with error message" do
        send_request :post, api_v1_users_forgot_password_path,
          params: { user: { email: "invalid@example.com" } }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          "notice" => I18n.t("password.create.success")
        )
      end
    end
  end
end
