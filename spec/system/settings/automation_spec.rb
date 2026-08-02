# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings automation", type: :system, js: true do
  let(:company) { create(:company) }
  let(:user) { create(:user, current_workspace_id: company.id) }

  before do
    create(:employment, company:, user:)
    user.add_role :owner, company
    sign_in(user)
  end

  it "shows the Miru CLI commands on the dedicated automation page" do
    with_forgery_protection do
      visit "/settings/automation"

      expect(page).to have_content("Automation and CLI", wait: 10)
      expect(page).to have_content("Free for every plan", wait: 10)
      expect(page).to have_content("miru login --email you@example.com", wait: 10)
      expect(page).to have_content("miru invoice list", wait: 10)
    end
  end

  it "shows localized copy on the automation page" do
    user.update!(locale: "hi")

    with_forgery_protection do
      visit "/settings/automation"

      expect(page).to have_content("ऑटोमेशन और CLI", wait: 10)
      expect(page).to have_content("हर प्लान के लिए निःशुल्क", wait: 10)
      expect(page).to have_content("एक बार प्रमाणित करें", wait: 10)
      expect(page).to have_content(
        "miru login --email you@example.com",
        wait: 10
      )
    end
  end

  it "hides the upstream automation product in an internal workspace" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MIRU_INTERNAL_DEPLOYMENT").and_return("true")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("MIRU_ALLOWED_SIGNUP_EMAILS", "").and_return(user.email)

    with_forgery_protection do
      visit "/settings/automation"

      expect(page).to have_current_path("/settings/organization", wait: 10)
      expect(page).not_to have_content("Automation and CLI")
      expect(page).not_to have_content("github.com/saeloun/miru-web")
    end
  end
end
