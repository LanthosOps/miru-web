# frozen_string_literal: true

namespace :internal_deployment do
  desc "Create or attach the first approved Lanthos Ops owner"
  task bootstrap_owner: :environment do
    user = InternalDeploymentBootstrapOwner.process
    puts "Internal owner is ready: #{user.email}"
  rescue InternalDeploymentBootstrapOwner::InvalidConfiguration, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    abort error.message
  end

  desc "Verify that internal deployment mode can be enabled safely"
  task verify: :environment do
    InternalDeploymentPreflight.verify!
    puts "Internal deployment preflight passed for #{InternalDeployment.allowed_emails.length} approved email(s)."
  rescue InternalDeploymentPreflight::UnsafeConfiguration => error
    abort error.message
  end
end
