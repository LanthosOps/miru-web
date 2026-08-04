# frozen_string_literal: true

require "digest"

module Idempotency
  class Store
    CACHE_TTL = 24.hours
    MAX_KEY_BYTES = 100

    class InvalidKeyError < StandardError; end
    class PayloadMismatchError < StandardError; end

    class << self
      def fetch(scope:, key:, request_digest: nil, max_key_bytes: nil, cache_if: nil, serialize: nil, deserialize: nil)
        return yield if key.blank?

        validate_key!(key, max_key_bytes:)

        cache_if ||= ->(_result) { true }
        serialize ||= ->(result) { result }
        deserialize ||= ->(payload) { payload }
        digest = key_digest(scope:, key:)

        ApplicationRecord.transaction(requires_new: true) do
          acquire_advisory_lock(digest)
          MCPIdempotencyRecord.expired.delete_all

          cached = MCPIdempotencyRecord.find_by(key_digest: digest)
          return deserialize.call(replay_payload(cached, request_digest:)) if cached

          result = yield
          cache_result(digest, result, request_digest:, serialize:) if cache_if.call(result)
          result
        end
      end

      def key_digest(scope:, key:)
        Digest::SHA256.hexdigest(build_key(scope:, key:))
      end

      private

        def validate_key!(key, max_key_bytes:)
          return unless max_key_bytes
          return if key.to_s.bytesize <= max_key_bytes

          raise InvalidKeyError, "Idempotency-Key must be #{max_key_bytes} bytes or fewer"
        end

        def cache_result(key_digest, result, request_digest:, serialize:)
          payload = serialize.call(result)
          response = request_digest ? { "request_digest" => request_digest, "payload" => payload } : payload

          MCPIdempotencyRecord.create!(
            key_digest:,
            response:,
            expires_at: CACHE_TTL.from_now
          )
        end

        def replay_payload(cached, request_digest:)
          return cached.response unless request_digest

          if cached.response["request_digest"] != request_digest
            raise PayloadMismatchError, "Idempotency-Key was already used with different request data"
          end

          cached.response.fetch("payload")
        end

        def acquire_advisory_lock(key_digest)
          connection = ApplicationRecord.connection
          return unless connection.adapter_name == "PostgreSQL"

          lock_id = [key_digest].pack("H*").unpack1("q>")
          connection.execute("SELECT pg_advisory_xact_lock(#{lock_id})")
        end

        def build_key(scope:, key:)
          "#{scope}:#{key}"
        end
    end
  end
end
