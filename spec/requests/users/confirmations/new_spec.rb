# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::Confirmations#new", type: :request do
  it "uses Lanthos branding for internal deployments" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")

    get new_user_confirmation_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Lanthos Ops")
    expect(response.body).not_to include("Miru logo")
  end
end
