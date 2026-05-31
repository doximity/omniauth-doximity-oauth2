# frozen_string_literal: true

require "omniauth/strategies/oauth2"
require "omniauth-doximity-oauth2/crypto"
require "omniauth-doximity-oauth2/errors"
require "active_support/core_ext/hash/indifferent_access"
require "uri"
require "rack/utils"
require "securerandom"
require "jwt"
require "faraday"
require "multi_json"

module OmniAuth
  module Strategies
    # Doximity OmniAuth strategy.
    class DoximityOauth2 < OmniAuth::Strategies::OAuth2 # rubocop:disable Metrics/ClassLength
      DEFAULT_SCOPE = "openid profile:read:basic"
      ID_TOKEN_ALGORITHMS = ["RS256"].freeze
      ID_TOKEN_REQUIRED_CLAIMS = %w[iss aud exp iat sub nonce].freeze

      option :name, "doximity"

      option :pkce, true

      option :id_token_algorithms, ID_TOKEN_ALGORITHMS

      option :authorize_options, %i[scope prompt theme login_hint]

      option :client_options, {
        site: "https://auth.doximity.com",
        authorize_url: "/oauth/authorize",
        token_url: "/oauth/token",
        jwks_url: "/.well-known/jwks.json"
      }

      option :auth_token_params, {
        mode: :header
      }

      uid { raw_subject_info["sub"] }

      info do
        prune({
                name: raw_subject_info["name"],
                given_name: raw_subject_info["given_name"],
                middle_name: raw_subject_info["middle_name"],
                family_name: raw_subject_info["family_name"],
                primary_email: raw_subject_info["primary_email"],
                emails: raw_subject_info["emails"],
                profile_photo_url: raw_subject_info["profile_photo_url"],
                credentials: raw_subject_info["credentials"],
                specialty: raw_subject_info["specialty"],
                permissions: raw_subject_info["permissions"]
              })
      end

      extra do
        prune({
                raw_subject_info: raw_subject_info,
                raw_credential_info: raw_credential_info
              })
      end

      credentials do
        prune({
                access_token: raw_credential_info["access_token"],
                refresh_token: raw_credential_info["refresh_token"],
                expires_at: raw_credential_info["expires_at"],
                scope: raw_credential_info["scope"],
                token_type: raw_credential_info["token_type"]
              })
      end

      def raw_subject_info
        @raw_subject_info ||= parse_id_token(access_token["id_token"] || access_token.get("/oauth/userinfo").body) || {}
      end

      def raw_credential_info
        @raw_credential_info ||= access_token.to_hash.with_indifferent_access
      end

      def authorize_params # rubocop:disable Metrics/AbcSize
        super.tap do |params|
          options[:authorize_options].each do |v|
            params[v.to_sym] = request.params[v.to_s] if request.params[v.to_s]
          end

          params[:scope] = get_scope(params)
          params[:nonce] = SecureRandom.hex(24) if oidc_scope?(params[:scope])

          # Ensure state is persisted
          session['omniauth.state'] = params[:state] if params[:state]
          session["omniauth.nonce"] = params[:nonce] if params[:nonce]
        end
      end

      private

      def get_scope(params)
        raw_scope = params[:scope] || DEFAULT_SCOPE
        scope_list = raw_scope.split(" ").map { |item| item.split(",") }.flatten
        scope_list.join(" ")
      end

      def parse_id_token(token) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        _, header = JWT.decode(token, nil, false)
        validate_id_token_algorithm!(header)

        keys = request_keys

        public_key_params = keys.find { |key| key["kid"] == header["kid"] }
        raise JWT::DecodeError, "No matching JWK for id_token" unless public_key_params

        rsa_key = OmniAuth::DoximityOauth2::Crypto.create_rsa_key(public_key_params["n"], public_key_params["e"])

        body, = JWT.decode(token, rsa_key.public_key, true, id_token_decode_options)
        validate_id_token_claims!(body)
        body
      rescue JWT::DecodeError => e
        raise OmniAuth::DoximityOauth2::JWTVerificationError.new(e, token)
      end

      def oidc_scope?(scope)
        scope.to_s.split.include?("openid")
      end

      def id_token_decode_options
        {
          algorithms: expected_id_token_algorithms,
          iss: expected_id_token_issuer,
          verify_iss: true,
          aud: options[:client_id],
          verify_aud: true,
          verify_iat: true,
          required_claims: ID_TOKEN_REQUIRED_CLAIMS
        }
      end

      def expected_id_token_algorithms
        Array(options[:id_token_algorithms]).map(&:to_s)
      end

      def expected_id_token_issuer
        options[:client_options][:site].to_s.sub(%r{/\z}, "")
      end

      def validate_id_token_algorithm!(header)
        return if expected_id_token_algorithms.include?(header["alg"])

        raise JWT::IncorrectAlgorithm, "Unexpected id_token algorithm #{header['alg']}"
      end

      def validate_id_token_claims!(body)
        validate_id_token_subject!(body)
        validate_id_token_authorized_party!(body)
        validate_id_token_nonce!(body)
      end

      def validate_id_token_subject!(body)
        return unless body["sub"].to_s.empty?

        raise JWT::InvalidSubError, "Missing subject"
      end

      def validate_id_token_authorized_party!(body)
        aud = Array(body["aud"])
        azp = body["azp"]

        raise JWT::InvalidAudError, "Missing authorized party" if aud.length > 1 && azp.to_s.empty?
        return if azp.nil? || azp.to_s == options[:client_id].to_s

        raise JWT::InvalidAudError, "Invalid authorized party"
      end

      def validate_id_token_nonce!(body)
        expected_nonce = session&.delete("omniauth.nonce")

        raise JWT::DecodeError, "Missing expected nonce" if expected_nonce.to_s.empty?
        return if body["nonce"].to_s == expected_nonce.to_s

        raise JWT::DecodeError, "Invalid nonce"
      end

      def callback_url
        options[:callback_url] || full_host + script_name + callback_path + callback_query_params
      end

      def callback_query_params
        request.params["callback_query_params"] || ""
      end

      def prune(hash)
        hash.delete_if do |_, val|
          prune(val) if val.is_a?(Hash)
          val.nil? || (val.respond_to?(:empty?) && val.empty?)
        end
      end

      def request_keys
        url = options[:client_options][:site] + options[:client_options][:jwks_url]
        response = Faraday.get(url)

        raise OmniAuth::DoximityOauth2::JWKSRequestError(url, response) if response.status != 200

        MultiJson.load(response.body)["keys"]
      end
    end
  end
end
