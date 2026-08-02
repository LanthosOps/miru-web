# frozen_string_literal: true

class CompanyAccessPayload
  def self.for(company)
    return {} unless company

    {
      "internal_deployment" => company.internal_deployment?,
      "billing_exempt" => company.billing_exempt?,
      "pro_access" => company.pro_access?,
      "current_plan_label" => company.current_plan_label,
      "trial_active" => company.trial_active?,
      "trial_ends_at" => company.internal_deployment? ? nil : company.trial_ends_at,
      "trial_expired" => company.trial_expired?,
      "subscription_status" => company.current_subscription_status,
      "team_member_limit" => company.team_member_limit,
      "used_team_seats" => company.used_team_seats,
      "reserved_team_seats" => company.reserved_team_seats,
      "team_member_limit_reached" => company.team_member_limit_reached?
    }
  end
end
