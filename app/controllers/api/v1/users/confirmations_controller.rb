# frozen_string_literal: true

class Api::V1::Users::ConfirmationsController < Devise::ConfirmationsController
  respond_to :json

  def create
    if InternalDeployment.enabled? && !InternalDeployment.signup_email_allowed?(resource_params[:email])
      return render_confirmation_notice(resource_params[:email])
    end

    self.resource = resource_class.send_confirmation_instructions(resource_params)
    if successfully_sent?(resource)
      render_confirmation_notice(resource.email)
    else
      respond_with_error(resource)
    end
  end

  private

    def render_confirmation_notice(email)
      render json: { notice: I18n.t("confirmation.send_instructions", email:) }, status: 200
    end

    def respond_with_error(resource)
      error_message = resource.errors.full_messages.first || "An error occurred"
      render json: { error: error_message }, status: 422
    end
end
