# frozen_string_literal: true

require "rails_helper"
require "timeout"

RSpec.describe Idempotency::Store do
  let_it_be(:company) { create(:company) }
  let_it_be(:client) { create(:client, company:) }
  let_it_be(:project) { create(:project, billable: true, client:) }
  let_it_be(:user) { create(:user, current_workspace_id: company.id) }

  it "creates one time entry when the same submission arrives concurrently" do
    key = "concurrent-time-entry"
    note = "Concurrent idempotency service test"
    first_started = Queue.new
    release_first = Queue.new
    second_started = Queue.new
    results = Queue.new
    errors = Queue.new
    calls = 0
    calls_mutex = Mutex.new
    create_entry = lambda do
      calls_mutex.synchronize { calls += 1 }
      entry = TimesheetEntry.create!(
        project:,
        user:,
        duration: 60,
        work_date: Date.current,
        note:,
        bill_status: :unbilled
      )
      { "id" => entry.id }
    end

    threads = [
      Thread.new do
        fetched = described_class.fetch(
          scope: "api:timesheet-entry:create:#{company.id}:#{user.id}",
          key:,
          request_digest: Digest::SHA256.hexdigest("same-request")
        ) do
          first_started << true
          release_first.pop
          create_entry.call
        end
        results << fetched
      rescue StandardError => error
        errors << error
      end
    ]

    Timeout.timeout(5) { first_started.pop }
    threads << Thread.new do
      second_started << true
      fetched = described_class.fetch(
        scope: "api:timesheet-entry:create:#{company.id}:#{user.id}",
        key:,
        request_digest: Digest::SHA256.hexdigest("same-request"),
        &create_entry
      )
      results << fetched
    rescue StandardError => error
      errors << error
    end

    Timeout.timeout(5) { second_started.pop }
    Timeout.timeout(5) { Thread.pass until threads.last.status == "sleep" }
    release_first << true
    threads.each { |thread| expect(thread.join(5)).to be_present }

    expect(errors).to be_empty
    expect(calls).to eq(1)
    expect(2.times.map { results.pop.fetch("id") }.uniq.one?).to be(true)
    expect(TimesheetEntry.where(note:).count).to eq(1)
  ensure
    release_first << true if release_first&.empty?
    threads&.each do |thread|
      next if thread.join(1)

      thread.kill
      thread.join
    end
    cleanup = Thread.new do
      TimesheetEntry.where(note:).delete_all if note
      digest = described_class.key_digest(
        scope: "api:timesheet-entry:create:#{company.id}:#{user.id}",
        key:
      )
      MCPIdempotencyRecord.where(key_digest: digest).delete_all
    end
    cleanup.join
  end
end
