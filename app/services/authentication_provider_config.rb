# frozen_string_literal: true

class AuthenticationProviderConfig
  class << self
    def google_enabled?
      ENV["GOOGLE_OAUTH_CLIENT_ID"].present? && ENV["GOOGLE_OAUTH_CLIENT_SECRET"].present?
    end

    def github_enabled?
      github_client_id.present? && github_client_secret.present?
    end

    private

      def github_client_id
        ENV["GITHUB_OAUTH_CLIENT_ID"] || ENV["MIRU_GH_CLIENT_ID"]
      end

      def github_client_secret
        ENV["GITHUB_OAUTH_CLIENT_SECRET"] || ENV["MIRU_GH_TOKEN"]
      end
  end
end
