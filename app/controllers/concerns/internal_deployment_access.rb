# frozen_string_literal: true

module InternalDeploymentAccess
  extend ActiveSupport::Concern

  included do
    before_action :enforce_internal_deployment_allowlist!
  end

  private

    def enforce_internal_deployment_allowlist!
      return unless current_user
      return if InternalDeployment.authenticated_user_allowed?(current_user)

      sign_out(current_user)

      if request.format.json?
        render json: { error: "This account is not approved for the internal workspace." }, status: 403
      else
        redirect_to new_user_session_path, alert: "This account is not approved for the internal workspace."
      end
    end
end
