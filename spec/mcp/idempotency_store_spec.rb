# frozen_string_literal: true

require "rails_helper"
require "timeout"

RSpec.describe MCP::Miru::IdempotencyStore do
  describe ".fetch" do
    let(:tool_name) { "miru.time.create" }
    let(:authorization) { "Bearer token-1" }
    let(:result) do
      MCP::Miru::ApiProxy::Result.new(
        status: 200,
        headers: { "content-type" => "application/json" },
        body: '{"ok":true}',
        json: { "ok" => true }
      )
    end

    it "does not cache results when idempotency key is blank" do
      calls = 0

      2.times do
        described_class.fetch(tool_name:, idempotency_key: nil, authorization:) do
          calls += 1
          result
        end
      end

      expect(calls).to eq(2)
    end

    it "returns cached result for repeated key and authorization" do
      calls = 0

      first = described_class.fetch(tool_name:, idempotency_key: "abc-123", authorization:) do
        calls += 1
        result
      end

      second = described_class.fetch(tool_name:, idempotency_key: "abc-123", authorization:) do
        calls += 1
        result
      end

      expect(calls).to eq(1)
      expect(second.to_h).to eq(first.to_h)
    end

    it "isolates cache entries by authorization digest" do
      calls = 0

      described_class.fetch(tool_name:, idempotency_key: "abc-123", authorization: "Bearer token-1") do
        calls += 1
        result
      end

      described_class.fetch(tool_name:, idempotency_key: "abc-123", authorization: "Bearer token-2") do
        calls += 1
        result
      end

      expect(calls).to eq(2)
    end

    it "does not cache unsuccessful results" do
      calls = 0
      failed_result = MCP::Miru::ApiProxy::Result.new(
        status: 500,
        headers: {},
        body: '{"error":"temporary"}',
        json: { "error" => "temporary" }
      )

      2.times do
        described_class.fetch(tool_name:, idempotency_key: "retryable", authorization:) do
          calls += 1
          failed_result
        end
      end

      expect(calls).to eq(2)
    end

    it "replays the first result when the same key arrives concurrently" do
      first_started = Queue.new
      release_first = Queue.new
      second_started = Queue.new
      results = Queue.new
      errors = Queue.new
      calls = 0
      calls_mutex = Mutex.new

      threads = [
        Thread.new do
          fetched = described_class.fetch(tool_name:, idempotency_key: "in-progress", authorization:) do
            calls_mutex.synchronize { calls += 1 }
            first_started << true
            release_first.pop
            result
          end
          results << fetched
        rescue StandardError => error
          errors << error
        end
      ]

      Timeout.timeout(5) { first_started.pop }
      threads << Thread.new do
        second_started << true
        fetched = described_class.fetch(tool_name:, idempotency_key: "in-progress", authorization:) do
          calls_mutex.synchronize { calls += 1 }
          result
        end
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
      expect(2.times.map { results.pop.to_h }.uniq).to eq([result.to_h])
    ensure
      release_first << true if release_first&.empty?
      threads&.each do |thread|
        next if thread.join(1)

        thread.kill
        thread.join
      end
      digest = described_class.send(
        :key_digest,
        tool_name:,
        idempotency_key: "in-progress",
        authorization:
      )
      cleanup = Thread.new do
        MCPIdempotencyRecord.where(key_digest: digest).delete_all
      end
      cleanup.join
    end

    it "retries expired results" do
      digest = described_class.send(
        :key_digest,
        tool_name:,
        idempotency_key: "expired",
        authorization:
      )
      MCPIdempotencyRecord.create!(
        key_digest: digest,
        response: result.to_h,
        expires_at: 1.second.ago
      )

      calls = 0
      described_class.fetch(tool_name:, idempotency_key: "expired", authorization:) do
        calls += 1
        result
      end

      expect(calls).to eq(1)
    end
  end
end
