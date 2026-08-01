# frozen_string_literal: true

class Api::V1::Users::RegistrationsController < Devise::RegistrationsController
  include SameOriginAuthentication

  SIGNUP_ATTRIBUTION_KEYS = %i[utm_source utm_medium utm_campaign utm_term utm_content].freeze

  respond_to :json
  protect_from_forgery with: :null_session, only: :create
  before_action :reject_cross_origin_authentication!, only: :create
  before_action :require_allowed_signup_email!, only: :create

  def respond_with(user, _opts = {})
    if user.errors.present?
      render json: { error: user.errors }, status: 422
    else
      Analytics::TrackingService.new(user:).track_signup(signup_attribution)

      render json: {
        notice: I18n.t("devise.registrations.signed_up"),
        email: user.email,
        agent_payment_options: {
          stripe_link_cli: Subscriptions::StripeLinkCliPaymentOption.signup_payload
        }
      }, status: 200
    end
  end

  private

    def require_allowed_signup_email!
      allowed_emails = ENV.fetch("MIRU_ALLOWED_SIGNUP_EMAILS", "")
        .split(/[\s,]+/)
        .filter_map { |email| email.strip.downcase.presence }
      return if allowed_emails.empty?
      return if allowed_emails.include?(sign_up_params[:email].to_s.strip.downcase)

      render json: { error: "Sign-up is not available for this email." }, status: :forbidden
    end

    def sign_up_params
      params.require(:user).permit(
        :first_name, :last_name, :email, :password, :password_confirmation, :locale
      )
    end

    def signup_attribution
      params.require(:user).permit(*SIGNUP_ATTRIBUTION_KEYS).to_h.transform_values { |value| value.to_s[0, 255] }
    end
end
