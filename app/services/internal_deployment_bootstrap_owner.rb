# frozen_string_literal: true

class InternalDeploymentBootstrapOwner
  class InvalidConfiguration < StandardError; end

  def self.process
    new.process
  end

  def process
    validate_configuration!

    ActiveRecord::Base.transaction do
      user = find_or_create_user!
      company = resolve_company(user)
      attach_owner!(user, company)
      user
    end
  end

  private

    def validate_configuration!
      raise InvalidConfiguration, "MIRU_INTERNAL_DEPLOYMENT must be true" unless InternalDeployment.enabled?
      raise InvalidConfiguration, "An approved bootstrap owner email is required" if owner_email.blank?
      raise InvalidConfiguration, "Bootstrap owner email must be in MIRU_ALLOWED_SIGNUP_EMAILS" unless InternalDeployment.signup_email_allowed?(owner_email)
      return if existing_user? || password.present?

      raise InvalidConfiguration, "MIRU_BOOTSTRAP_OWNER_PASSWORD is required when creating the owner"
    end

    def find_or_create_user!
      return existing_user if existing_user

      User.create!(
        email: owner_email,
        first_name: ENV.fetch("MIRU_BOOTSTRAP_OWNER_FIRST_NAME", "Lanthos"),
        last_name: ENV.fetch("MIRU_BOOTSTRAP_OWNER_LAST_NAME", "Owner"),
        password:,
        password_confirmation: password,
        confirmed_at: Time.current
      )
    end

    def resolve_company(user)
      requested_company_id = ENV["MIRU_BOOTSTRAP_COMPANY_ID"].presence
      return Company.find(requested_company_id) if requested_company_id
      return user.current_workspace if user.current_workspace
      return user.companies.first if user.companies.exists?
      return Company.first if Company.one?

      if Company.many?
        raise InvalidConfiguration, "MIRU_BOOTSTRAP_COMPANY_ID is required when more than one company exists"
      end

      Company.create!(
        name: ENV.fetch("MIRU_BOOTSTRAP_COMPANY_NAME", "Lanthos Ops"),
        standard_price: 0,
        country: ENV.fetch("MIRU_BOOTSTRAP_COMPANY_COUNTRY", "CA"),
        base_currency: ENV.fetch("MIRU_BOOTSTRAP_COMPANY_CURRENCY", "CAD"),
        timezone: ENV.fetch("MIRU_BOOTSTRAP_COMPANY_TIMEZONE", "Eastern Time (US & Canada)"),
        fiscal_year_end: "December",
        date_format: "MM-DD-YYYY"
      )
    end

    def attach_owner!(user, company)
      employment = Employment.find_or_create_by!(user:, company:)
      employment.undiscard! if employment.discarded?
      user.confirm unless user.confirmed?
      user.unlock_access! if user.access_locked?
      user.update!(current_workspace: company) unless user.current_workspace_id == company.id
      user.add_role(:owner, company) unless user.has_role?(:owner, company)
      NotificationPreference.find_or_create_by!(user:, company:)
    end

    def owner_email
      @owner_email ||= begin
        configured = ENV["MIRU_BOOTSTRAP_OWNER_EMAIL"].presence
        configured || InternalDeployment.allowed_emails.one? && InternalDeployment.allowed_emails.first
      end.to_s.strip.downcase
    end

    def password
      ENV["MIRU_BOOTSTRAP_OWNER_PASSWORD"].to_s
    end

    def existing_user
      @existing_user ||= User.kept.find_by("LOWER(email) = ?", owner_email)
    end

    def existing_user?
      existing_user.present?
    end
end
