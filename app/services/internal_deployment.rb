# frozen_string_literal: true

class InternalDeployment
  FLAG = "MIRU_INTERNAL_DEPLOYMENT"
  ALLOWLIST = "MIRU_ALLOWED_SIGNUP_EMAILS"

  class << self
    def enabled?
      ActiveModel::Type::Boolean.new.cast(ENV[FLAG])
    end

    def allowed_emails
      ENV.fetch(ALLOWLIST, "")
        .split(/[\s,]+/)
        .filter_map { |email| normalize_email(email).presence }
        .uniq
    end

    def signup_email_allowed?(email)
      return true unless enabled?

      allowed_emails.include?(normalize_email(email))
    end

    def authenticated_user_allowed?(user)
      !enabled? || signup_email_allowed?(user&.email)
    end

    private

      def normalize_email(email)
        email.to_s.strip.downcase
      end
  end
end
