require "omniauth/strategies/oauth2"
require "uri"
require "rack/utils"
require "jwt"
require "net/http"
require "json"

module OmniAuth
  module Strategies
    class Doximity < OmniAuth::Strategies::OAuth2
      DEFAULT_SCOPE = "openid profile:read:basic"

      option :name, "doximity"

      option :pkce, true

      option :authorize_options, [:scope]

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
                emails: raw_subject_info["emails"],
                permissions: raw_subject_info["permissions"],
                profile_photo_url: raw_subject_info["profile_photo_url"]
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
                access_token: raw_credential_info[:access_token],
                refresh_token: raw_credential_info[:refresh_token],
                expires_at: raw_credential_info[:expires_at],
                scope: raw_credential_info["scope"],
                token_type: raw_credential_info["token_type"]
              })
      end

      def raw_subject_info
        @raw_subject_info ||= parse_id_token(access_token["id_token"] || access_token.get("/oauth/userinfo").body) || {}
      end

      def raw_credential_info
        @raw_credential_info ||= access_token.to_hash
      end

      def authorize_params
        super.tap do |params|
          options[:authorize_options].each do |v|
            if request.params[v]
              params[v.to_sym] = request.params[v]
            end
          end

          params[:scope] = get_scope(params)
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
        rsa_key = create_rsa_key(public_key_params["n"], public_key_params["e"])

        body, _ = JWT.decode(token, rsa_key.public_key, true, { algorithm: header["alg"] })
        body
      end

      def callback_url
        options[:callback_url] || full_host + script_name + callback_path
      end

      def prune(hash)
        hash.delete_if do |_, val|
          prune(val) if val.is_a?(Hash)
          val.nil? || (val.respond_to?(:empty?) && val.empty?)
        end
      end

      def request_keys
        url = options[:client_options][:site] + options[:client_options][:jwks_url]
        uri = URI(url)
        response = Net::HTTP.get(uri)
        JSON.parse(response)["keys"]
      end

      def create_rsa_key(n, e)
        key = OpenSSL::PKey::RSA.new
        key.set_key(OpenSSL::BN.new(Base64.urlsafe_decode64(n), 2), OpenSSL::BN.new(Base64.urlsafe_decode64(e), 2), nil)
      end
    end
  end
end
