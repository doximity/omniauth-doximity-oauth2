module Omniauth
  module Doximity
    class JWKSRequestError < StandardError
      MESSAGE = "Failed to request public keys for user info verification"
      attr_reader :url
      attr_reader :response

      def initialize(url, response)
        @url = url
        @response = response
        super(MESSAGE)
      end
    end

    class JWTVerificationError < StandardError
      MESSAGE = "Failed to verify user info JWT"
      attr_reader :token
      attr_reader :error

      def initialize(error, token)
        @token = token
        super(error.message)
      end
    end
  end
end
