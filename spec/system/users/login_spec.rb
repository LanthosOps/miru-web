# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sign-in", type: :system, js: true do
  let(:company) { create(:company) }
  let(:user) { create(:user, current_workspace_id: company.id) }

  context "when user is an admin, owner, employee" do
    before do
      create(:employment, company:, user:)
      user.add_role :admin, company
    end

    it "displays an error message with invalid credentials" do
      with_forgery_protection do
        visit "/login"
        wait_for_react_app

        type_login_field("email", "invalid@example.com")
        type_login_field("password", "password")

        click_on "Sign in"

        expect(page).to have_current_path("/login")
        expect(page).to have_text("Invalid email or password")
      end
    end

    it "shows both Google and GitHub sign-in options" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GOOGLE_OAUTH_CLIENT_ID").and_return("google-client")
      allow(ENV).to receive(:[]).with("GOOGLE_OAUTH_CLIENT_SECRET").and_return("google-secret")
      allow(ENV).to receive(:[]).with("GITHUB_OAUTH_CLIENT_ID").and_return("github-client")
      allow(ENV).to receive(:[]).with("GITHUB_OAUTH_CLIENT_SECRET").and_return("github-secret")

      with_forgery_protection do
        visit "/login"
        wait_for_react_app

        expect(page).to have_button("Continue with Google")
        expect(page).to have_button("Continue with GitHub")
      end
    end

    it "hides OAuth options when provider credentials are unavailable" do
      allow(ENV).to receive(:[]).and_call_original
      %w[
        GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET
        GITHUB_OAUTH_CLIENT_ID GITHUB_OAUTH_CLIENT_SECRET
        MIRU_GH_CLIENT_ID MIRU_GH_TOKEN
      ].each { |key| allow(ENV).to receive(:[]).with(key).and_return(nil) }

      with_forgery_protection do
        visit "/login"
        wait_for_react_app

        expect(page).not_to have_button("Continue with Google")
        expect(page).not_to have_button("Continue with GitHub")
        expect(page).to have_button("Sign in", disabled: true)
      end
    end

    it "preserves dark mode on forgot password page" do
      with_forgery_protection do
        visit "/login"
        wait_for_react_app

        page.execute_script(<<~JS)
          localStorage.setItem("miru-theme", "dark");
          document.documentElement.classList.add("dark");
        JS
        click_link "Forgot password?"

        expect(page).to have_current_path("/password/new")
        expect(page).to have_css("button", text: "Send Reset Link", wait: 10)
        expect(page.evaluate_script("document.documentElement.classList.contains('dark')")).to be(true)
      end
    end
  end
end
