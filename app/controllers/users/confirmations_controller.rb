# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  respond_to :json

  def create
    if InternalDeployment.enabled? && !InternalDeployment.signup_email_allowed?(resource_params[:email])
      redirect_to new_user_confirmation_path,
        notice: "If the address is eligible, confirmation instructions will be sent."
    else
      super
    end
  end

  protected

    def after_confirmation_path_for(resource_name, resource)
      "/email_verification_success"
    end
end
