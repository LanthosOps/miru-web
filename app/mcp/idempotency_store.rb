# frozen_string_literal: true

require "digest"

module MCP
  module Miru
    class IdempotencyStore
      CACHE_TTL = ::Idempotency::Store::CACHE_TTL

      class << self
        def fetch(tool_name:, idempotency_key:, authorization:, &block)
          ::Idempotency::Store.fetch(
            scope: scope(tool_name:, authorization:),
            key: idempotency_key,
            cache_if: ->(result) { result.success? },
            serialize: ->(result) { result.to_h },
            deserialize: ->(payload) { MCP::Miru::ApiProxy::Result.from_h(payload) },
            &block
          )
        end

        private

          def key_digest(tool_name:, idempotency_key:, authorization:)
            ::Idempotency::Store.key_digest(
              scope: scope(tool_name:, authorization:),
              key: idempotency_key
            )
          end

          def scope(tool_name:, authorization:)
            authorization_digest = Digest::SHA256.hexdigest(authorization.to_s)
            "mcp:idempotency:#{tool_name}:#{authorization_digest}"
          end
      end
    end
  end
end
