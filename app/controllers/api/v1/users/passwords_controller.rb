# frozen_string_literal: true

class Api::V1::Users::PasswordsController < Devise::PasswordsController
  include InternalDeploymentAccess

  respond_to :json

  def create
    unless InternalDeployment.signup_email_allowed?(resource_params[:email])
      return render json: { notice: I18n.t("password.create.success") }, status: 200
    end

    self.resource = resource_class.send_reset_password_instructions(resource_params)
    if successfully_sent?(resource)
      render json: { notice: I18n.t("password.create.success") }, status: 200
    else
      respond_with_error(resource)
    end
  end

  def update
    reset_user = User.with_reset_password_token(password_params[:reset_password_token])
    return unless reset_user.nil? || ensure_internal_deployment_user_allowed!(reset_user)

    user = User.reset_password_by_token(password_params)
    if user.errors.empty?
      unless user.active_for_authentication?
        return render json: {
          error: I18n.t("devise.failure.inactive"),
          errors: [I18n.t("devise.failure.inactive")]
        }, status: 422
      end

      sign_in(user) if Devise.sign_in_after_reset_password
      safe_user = user.as_json(only: %i[id email first_name last_name current_workspace_id])
      render json: { notice: I18n.t("password.update.success"), user: safe_user }, status: 200
    else
      respond_with_error(user)
    end
  end

  private

    def password_params
      params.require(:user).permit(:reset_password_token, :password, :password_confirmation)
    end

    def respond_with_error(resource)
      error_message = resource.errors.full_messages.first || "An error occurred"
      render json: { error: error_message }, status: 422
    end
end
