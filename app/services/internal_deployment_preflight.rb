# frozen_string_literal: true

class InternalDeploymentPreflight
  class UnsafeConfiguration < StandardError; end

  ACTIVE_SUBSCRIPTION_STATUSES = %w[active trialing past_due].freeze

  def self.verify!
    new.verify!
  end

  def verify!
    failures = errors
    raise UnsafeConfiguration, failures.join("\n") if failures.any?

    true
  end

  def errors
    return ["MIRU_INTERNAL_DEPLOYMENT must be true"] unless InternalDeployment.enabled?
    return ["MIRU_ALLOWED_SIGNUP_EMAILS must contain at least one approved owner"] if InternalDeployment.allowed_emails.empty?

    [billing_links_error, invitations_error, legacy_devise_invitations_error, owner_error].compact
  end

  private

    def billing_links_error
      companies = Company.where(billing_link_conditions)
      return unless companies.exists?

      identifiers = companies.limit(20).pluck(:id, :name).map { |id, name| "#{id}:#{name}" }.join(", ")
      "Billing identifiers and paid/trial states must be cleared before internal mode is enabled: #{identifiers}"
    end

    def billing_link_conditions
      Company.arel_table.then do |companies|
        condition = companies[:plan_tier].eq("paid")
          .or(companies[:subscription_status].in(ACTIVE_SUBSCRIPTION_STATUSES))
          .or(companies[:stripe_customer_id].not_eq(nil).and(companies[:stripe_customer_id].not_eq("")))

        if Company.column_names.include?("stripe_subscription_id")
          condition = condition.or(
            companies[:stripe_subscription_id].not_eq(nil).and(companies[:stripe_subscription_id].not_eq(""))
          )
        end

        condition
      end
    end

    def invitations_error
      invitations = Invitation.valid_invitations.where.not("LOWER(recipient_email) IN (?)", InternalDeployment.allowed_emails)
      return unless invitations.exists?

      identifiers = invitations.limit(20).pluck(:id, :recipient_email).map { |id, email| "#{id}:#{email}" }.join(", ")
      "Pending invitations for non-approved recipients must be revoked or allowed to expire: #{identifiers}"
    end

    def legacy_devise_invitations_error
      users = User.kept
        .where.not(invitation_token: [nil, ""])
        .where(invitation_accepted_at: nil)
        .where.not("LOWER(email) IN (?)", InternalDeployment.allowed_emails)
      return unless users.exists?

      identifiers = users.limit(20).pluck(:id, :email).map { |id, email| "#{id}:#{email}" }.join(", ")
      "Legacy Devise invitations for non-approved recipients must be revoked: #{identifiers}"
    end

    def owner_error
      approved_users = User.kept.where("LOWER(email) IN (?)", InternalDeployment.allowed_emails)
      return if approved_users.any? do |user|
        owner_company_ids = user.roles.where(name: "owner", resource_type: "Company").pluck(:resource_id)
        user.confirmed? && user.active_for_authentication? && user.employments.kept.exists?(company_id: owner_company_ids)
      end

      "No approved company owner exists. Run `bundle exec rake internal_deployment:bootstrap_owner` before startup."
    end
end
