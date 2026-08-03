# frozen_string_literal: true

require "digest"

class Api::V1::TimesheetEntryController < Api::V1::ApplicationController
  include DateRangeParamParsing

  class IdempotencyConflictError < StandardError; end

  rescue_from IdempotencyConflictError, with: :handle_idempotency_conflict

  skip_after_action :verify_authorized, only: [:index]
  after_action :verify_policy_scoped, only: [:index]

  def index
    policy_scope(TimesheetEntry)
    user = current_company.users.find(selected_user_id)
    data = TimeTrackingIndexService.new(
      current_user: current_user,
      user: user,
      company: current_company,
      from: parsed_date_param(:from) || 1.month.ago.beginning_of_month,
      to: parsed_date_param(:to) || 1.month.since.end_of_month,
      year: params[:year] || Date.today.year
    ).entries_payload

    render :index, locals: {
      entries: data[:entries],
      holiday_infos: data[:holiday_infos],
      leave_types: data[:leave_types],
      company: current_company
    }, status: 200
  end

  def create
    authorize TimesheetEntry
    render json: idempotent_create_payload
  end

  def update
    authorize current_timesheet_entry
    current_timesheet_entry.project = current_project
    current_timesheet_entry.update!(timesheet_entry_params)
    render json: { notice: I18n.t("timesheet_entry.update.message"), entry: current_timesheet_entry.snippet },
      status: 200
  end

  def destroy
    authorize current_timesheet_entry
    render json: { notice: I18n.t("timesheet_entry.destroy.message") } if current_timesheet_entry.discard!
  end

  private

    def selected_user_id
      return current_user.id unless current_user.has_role?(:owner, current_company) || current_user.has_role?(:admin, current_company)

      params[:user_id] || current_user.id
    end

    def current_project
      @_current_project ||= current_company.projects.kept.find(params[:project_id])
    end

    def current_timesheet_entry
      @_current_timesheet_entry ||= current_company.timesheet_entries.kept.find(params[:id])
    end

    def timesheet_entry_user
      if current_user.has_role?(:owner, current_company) || current_user.has_role?(:admin, current_company)
        return current_company.users.find(params[:user_id] || current_user.id)
      end

      return current_user if params[:user_id].blank? || params[:user_id].to_i == current_user.id

      raise Pundit::NotAuthorizedError
    end

    def timesheet_entry_params
      params.require(:timesheet_entry).permit(:project_id, :duration, :work_date, :note, :bill_status)
    end

    def idempotent_create_payload
      return create_payload if idempotency_key.blank?

      raise ActionController::BadRequest, "Idempotency-Key is too long" if idempotency_key.bytesize > 100

      TimesheetEntry.transaction do
        acquire_idempotency_lock
        MCPIdempotencyRecord.expired.delete_all
        cached = MCPIdempotencyRecord.find_by(key_digest: idempotency_digest)

        if cached
          replay_payload(cached)
        else
          payload = create_payload
          MCPIdempotencyRecord.create!(
            key_digest: idempotency_digest,
            response: {
              "request_digest" => idempotency_request_digest,
              "payload" => payload
            },
            expires_at: 24.hours.from_now
          )
          payload
        end
      end
    end

    def create_payload
      timesheet_entry = current_project.timesheet_entries.new(effective_timesheet_entry_params)
      timesheet_entry.user = timesheet_entry_user
      timesheet_entry.save!
      {
        notice: I18n.t("timesheet_entry.create.message"),
        entry: timesheet_entry.snippet
      }
    end

    def idempotency_key
      @_idempotency_key ||= request.headers["Idempotency-Key"].to_s.strip
    end

    def idempotency_digest
      @_idempotency_digest ||= Digest::SHA256.hexdigest(
        ["api", "timesheet-entry", "create", current_company.id, current_user.id, idempotency_key].join(":")
      )
    end

    def idempotency_request_digest
      @_idempotency_request_digest ||= Digest::SHA256.hexdigest(
        JSON.generate(
          {
            "project_id" => params[:project_id].to_s,
            "user_id" => (params[:user_id].presence || current_user.id).to_s,
            "timesheet_entry" => effective_timesheet_entry_params.to_h.deep_stringify_keys.sort.to_h
          }
        )
      )
    end

    def effective_timesheet_entry_params
      timesheet_entry_params.except(:project_id)
    end

    def replay_payload(cached)
      if cached.response["request_digest"] != idempotency_request_digest
        raise IdempotencyConflictError, "Idempotency-Key was already used with different time entry data"
      end

      cached.response.fetch("payload")
    end

    def handle_idempotency_conflict(exception)
      render json: { errors: exception.message }, status: 409
    end

    def acquire_idempotency_lock
      connection = ApplicationRecord.connection
      return unless connection.adapter_name == "PostgreSQL"

      lock_id = [idempotency_digest].pack("H*").unpack1("q>")
      connection.select_value("SELECT pg_advisory_xact_lock(#{lock_id})")
    end
end
