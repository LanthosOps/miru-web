# frozen_string_literal: true

class InternalDeviseMailer < Devise::Mailer
  INTERNAL_SUBJECTS = {
    confirmation_instructions: "Verify your Lanthos Ops email",
    email_changed: "Your Lanthos Ops email changed",
    password_change: "Your Lanthos Ops password was changed",
    reset_password_instructions: "Reset your Lanthos Ops password",
    unlock_instructions: "Unlock your Lanthos Ops account"
  }.freeze

  protected

    def subject_for(key)
      return super unless InternalDeployment.enabled?

      INTERNAL_SUBJECTS.fetch(key) { key.to_s.humanize }
    end
end
