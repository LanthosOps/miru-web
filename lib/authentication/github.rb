# frozen_string_literal: true

module Authentication
  class Github
    PROVIDER = "github"

    def initialize(user_data)
      @user_data = user_data
    end

    def user!
      return if @user_data.blank? || github_id.blank? || candidate_emails.blank?

      identity_user = Identity.github_auth.find_by(uid: github_id)&.user
      return identity_user if identity_user && InternalDeployment.authenticated_user_allowed?(identity_user)
      return if identity_user

      existing_user = User.find_by(email: candidate_emails)
      if existing_user
        return unless InternalDeployment.authenticated_user_allowed?(existing_user)

        existing_user.identities.find_or_create_by(provider: PROVIDER, uid: github_id)
        return existing_user
      end

      return unless signup_email

      create_user!
    end

    private

      def create_user!
        user = User.new(
          email: signup_email,
          first_name: first_name,
          last_name:,
          password: Devise.friendly_token[0, 20]
        )
        user.skip_confirmation!
        user.save!
        user.identities.create!(provider: PROVIDER, uid: github_id)

        user
      end

      def signup_email
        @signup_email ||= candidate_emails.find { |candidate| InternalDeployment.signup_email_allowed?(candidate) }
      end

      def email
        @user_data.info.email
      end

      def candidate_emails
        @candidate_emails ||= begin
          addresses = verified_emails.presence || [email]
          addresses.compact_blank.uniq
        end
      end

      def verified_emails
        Array(@user_data.extra&.all_emails).filter_map do |entry|
          next unless entry["verified"]

          entry["email"]
        end
      end

      def first_name
        @user_data.info.first_name.presence || name_parts.first || username
      end

      def last_name
        @user_data.info.last_name.presence || name_parts.drop(1).join(" ").presence || username
      end

      def username
        @user_data.info.nickname.presence || email.split("@").first
      end

      def name_parts
        @name_parts ||= @user_data.info.name.to_s.split
      end

      def github_id
        @user_data.uid
      end
  end
end
