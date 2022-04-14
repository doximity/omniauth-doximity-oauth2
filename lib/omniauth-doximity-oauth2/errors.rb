# frozen_string_literal: true

module Omniauth
  module DoximityOauth2
    # Error for failed request to get public keys, for JWK verification
    class JWKSRequestError < StandardError
      MESSAGE = "Failed to request public keys for user info verification"
      attr_reader :url, :response

      def initialize(url, response)
        @url = url
        @response = response
        super(MESSAGE)
      end
    end

    # Error for failed JWK verifications
    class JWTVerificationError < StandardError
      MESSAGE = "Failed to verify user info JWT"
      attr_reader :token, :error

      def initialize(error, token)
        @token = token
        super(error.message)
      end
    end
  end
end
