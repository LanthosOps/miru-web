# frozen_string_literal: true

namespace :internal_deployment do
  desc "Verify that internal deployment mode can be enabled safely"
  task verify: :environment do
    abort "MIRU_INTERNAL_DEPLOYMENT must be true" unless InternalDeployment.enabled?
    abort "MIRU_ALLOWED_SIGNUP_EMAILS must contain at least one approved owner" if InternalDeployment.allowed_emails.empty?

    active_subscriptions = Company.where(
      "plan_tier = :paid OR subscription_status IN (:statuses)",
      paid: "paid",
      statuses: %w[active trialing past_due]
    )

    if active_subscriptions.exists?
      identifiers = active_subscriptions.limit(20).pluck(:id, :name).map { |id, name| "#{id}:#{name}" }.join(", ")
      abort "Active Miru subscriptions must be canceled before internal mode is enabled: #{identifiers}"
    end

    puts "Internal deployment preflight passed for #{InternalDeployment.allowed_emails.length} approved email(s)."
  end
end
