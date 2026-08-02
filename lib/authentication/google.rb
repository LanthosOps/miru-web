# frozen_string_literal: true

module Authentication
  class Google
    PROVIDER = "google_oauth2"

    def initialize(user_data)
      @user_data = user_data
    end

    def user!
      return if @user_data.blank? || google_id.blank?

      identity_user = Identity.google_auth.find_by(uid: google_id)&.user
      return identity_user if identity_user && InternalDeployment.authenticated_user_allowed?(identity_user)
      return if identity_user

      existing_user = User.find_by_email(email)
      if existing_user
        return unless InternalDeployment.authenticated_user_allowed?(existing_user)

        existing_user.identities.find_or_create_by(provider: PROVIDER, uid: google_id)
        return existing_user
      end

      return unless InternalDeployment.signup_email_allowed?(email)

      create_user!
    end

    private

      def create_user!
        user_first_name = first_name || email.split("@").first
        user = User.new(
          email:,
          first_name: user_first_name,
          last_name:,
          password: Devise.friendly_token[0, 20]
        )
        user.skip_confirmation!
        user.save!
        user.identities.create!(provider: PROVIDER, uid: google_id)
        user
      end

      def email
        @user_data.info.email
      end

      def first_name
        @user_data.info.first_name
      end

      def last_name
        @user_data.info.last_name
      end

      def google_id
        @user_data.uid
      end
  end
end
