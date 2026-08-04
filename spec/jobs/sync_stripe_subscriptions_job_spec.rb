# frozen_string_literal: true

require "rails_helper"

RSpec.describe SyncStripeSubscriptionsJob, type: :job do
  it "syncs every company with a Stripe customer" do
    company_one = create(:company, stripe_customer_id: "cus_1")
    company_two = create(:company, stripe_customer_id: "cus_2")
    create(:company, stripe_customer_id: nil)

    expect {
      described_class.perform_now
    }.to have_enqueued_job(SyncStripeSubscriptionCompanyJob).with(company_one.id).on_queue("billing_sync")
      .and have_enqueued_job(SyncStripeSubscriptionCompanyJob).with(company_two.id).on_queue("billing_sync")
  end

  it "enqueues no billing sync work in an internal deployment" do
    create(:company, stripe_customer_id: "cus_internal")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")

    expect { described_class.perform_now }.not_to have_enqueued_job(SyncStripeSubscriptionCompanyJob)
  end
end
