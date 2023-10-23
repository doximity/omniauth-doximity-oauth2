# frozen_string_literal: true

require "omniauth/strategies/oauth2"
require "omniauth-doximity-oauth2/crypto"
require "omniauth-doximity-oauth2/errors"
require "active_support/core_ext/hash/indifferent_access"
require "uri"
require "rack/utils"
require "jwt"
require "faraday"
require "multi_json"

module OmniAuth
  module Strategies
    # Doximity OmniAuth strategy.
    class DoximityOauth2 < OmniAuth::Strategies::OAuth2
      DEFAULT_SCOPE = "openid profile:read:basic"

      option :name, "doximity"

      option :pkce, true

      option :authorize_options, %i[scope prompt theme]

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

          # Ensure state is persisted
          session['omniauth.state'] = params[:state] if params[:state]
        end
      end

      private

      def get_scope(params)
        raw_scope = params[:scope] || DEFAULT_SCOPE
        scope_list = raw_scope.split(" ").map { |item| item.split(",") }.flatten
        scope_list.join(" ")
      end

      def parse_id_token(token)
        _, header = JWT.decode(token, nil, false)

        keys = request_keys

        public_key_params = keys.find { |key| key["kid"] == header["kid"] }
        rsa_key = OmniAuth::DoximityOauth2::Crypto.create_rsa_key(public_key_params["n"], public_key_params["e"])

        body, = JWT.decode(token, rsa_key.public_key, true, { algorithm: header["alg"] })
        body
      rescue JWT::VerificationError => e
        raise OmniAuth::DoximityOauth2::JWTVerificationError(e, token)
      end

      def callback_url
        options[:callback_url] || full_host + script_name + callback_path + callback_query_params
      end

      def callback_query_params
        request.params[:callback_query_params] || ""
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
