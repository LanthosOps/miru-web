# frozen_string_literal: true

class SendWeeklyReminderToUserMailer < ApplicationMailer
  def notify_user_about_missed_entries
    recipients = params[:recipients]
    @company = params[:company_name]
    @name = params[:name]

    @starting_date = params[:start_date].to_date
    @ending_date = params[:end_date].to_date

    with_recipient_locale(recipient_user_from(recipients)) do
      subject = if InternalDeployment.enabled?
        "Complete your Lanthos Ops timesheet for last week"
      else
        I18n.t("mailers.send_weekly_reminder_to_user_mailer.notify_user_about_missed_entries.subject")
      end

      mail(
        to: recipients,
        subject:,
        reply_to: default_reply_to_address
      )
    end
  end
end
