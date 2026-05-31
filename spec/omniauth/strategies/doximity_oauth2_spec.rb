# frozen_string_literal: true

require "spec_helper"
require "base64"
require "json"
require "omniauth-doximity-oauth2"
require "openssl"
require "stringio"

describe OmniAuth::Strategies::DoximityOauth2 do
  let(:request) { double("Request", params: {}, cookies: {}, env: {}) }
  let(:app) do
    lambda do
      [200, {}, ["Hello."]]
    end
  end

  subject do
    OmniAuth::Strategies::DoximityOauth2.new(app, "appid", "secret", @options || {}).tap do |strategy|
      allow(strategy).to receive(:request) do
        request
      end
    end
  end

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe "#client_options" do
    it "has correct site" do
      expect(subject.client.site).to eq("https://auth.doximity.com")
    end

    it "has correct authorize_url" do
      expect(subject.client.options[:authorize_url]).to eq("/oauth/authorize")
    end

    it "has correct token_url" do
      expect(subject.client.options[:token_url]).to eq("/oauth/token")
    end

    it "has correct jwks_url" do
      expect(subject.client.options[:jwks_url]).to eq("/.well-known/jwks.json")
    end

    describe "overrides" do
      context "as strings" do
        it "should allow overriding the site" do
          @options = { client_options: { "site" => "https://example.com" } }
          expect(subject.client.site).to eq("https://example.com")
        end

        it "should allow overriding the authorize_url" do
          @options = { client_options: { "authorize_url" => "/example" } }
          expect(subject.client.options[:authorize_url]).to eq("/example")
        end

        it "should allow overriding the token_url" do
          @options = { client_options: { "token_url" => "/example" } }
          expect(subject.client.options[:token_url]).to eq("/example")
        end

        it "should allow overriding the jwks_url" do
          @options = { client_options: { "jwks_url" => "/example" } }
          expect(subject.client.options[:jwks_url]).to eq("/example")
        end
      end

      context "as symbols" do
        it "should allow overriding the site" do
          @options = { client_options: { site: "https://example.com" } }
          expect(subject.client.site).to eq("https://example.com")
        end

        it "should allow overriding the authorize_url" do
          @options = { client_options: { authorize_url: "/example" } }
          expect(subject.client.options[:authorize_url]).to eq("/example")
        end

        it "should allow overriding the token_url" do
          @options = { client_options: { token_url: "/example" } }
          expect(subject.client.options[:token_url]).to eq("/example")
        end

        it "should allow overriding the jwks_url" do
          @options = { client_options: { jwks_url: "/example" } }
          expect(subject.client.options[:jwks_url]).to eq("/example")
        end
      end
    end
  end

  describe "#authorize_options" do
    %i[scope].each do |k|
      it "should support #{k}" do
        @options = { k => "http://someval" }
        expect(subject.authorize_params[k.to_s]).to eq("http://someval")
      end
    end

    describe "scope" do
      it "should leave base scopes as is" do
        @options = { scope: "profile:read:basic" }
        expect(subject.authorize_params["scope"]).to eq("profile:read:basic")
      end

      it "should join scopes" do
        @options = { scope: "profile:read:basic,profile:read:email" }
        expect(subject.authorize_params["scope"]).to eq("profile:read:basic profile:read:email")
      end

      it "should deal with whitespace when joining scopes" do
        @options = { scope: "profile:read:basic, profile:read:email" }
        expect(subject.authorize_params["scope"]).to eq("profile:read:basic profile:read:email")
      end

      it "should set default scope to openid profile:read:basic" do
        expect(subject.authorize_params["scope"]).to eq("openid profile:read:basic")
      end

      it "should support space delimited scopes" do
        @options = { scope: "profile:read:basic profile:read:email" }
        expect(subject.authorize_params["scope"]).to eq("profile:read:basic profile:read:email")
      end

      it "should add and store a nonce for openid scopes" do
        params = subject.authorize_params

        expect(params["nonce"]).not_to be_empty
        expect(subject.session["omniauth.nonce"]).to eq(params["nonce"])
      end
    end
  end

  describe "#parse_id_token" do
    let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
    let(:kid) { "test-key-id" }
    let(:nonce) { "expected-nonce" }
    let(:session) { { "omniauth.nonce" => nonce } }
    let(:claims) do
      {
        "iss" => "https://auth.doximity.com",
        "aud" => "appid",
        "azp" => "appid",
        "exp" => Time.now.to_i + 3600,
        "iat" => Time.now.to_i,
        "sub" => "subject-123",
        "nonce" => nonce,
        "name" => "Dox User"
      }
    end
    let(:jwk) do
      {
        "kid" => kid,
        "n" => base64url_uint(rsa_key.public_key.n),
        "e" => base64url_uint(rsa_key.public_key.e)
      }
    end

    before do
      allow(subject).to receive(:request_keys).and_return([jwk])
      allow(subject).to receive(:session).and_return(session)
    end

    it "accepts a valid RS256 id token for the configured issuer, client, and nonce" do
      expect(parse_id_token(signed_token)).to include(
        "sub" => "subject-123",
        "iss" => "https://auth.doximity.com",
        "aud" => "appid",
        "nonce" => nonce
      )
    end

    it "rejects unsigned id tokens" do
      token = JWT.encode(claims, nil, "none", kid: kid)

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens signed with unsupported algorithms" do
      token = JWT.encode(claims, "secret", "HS256", kid: kid)

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens with the wrong issuer" do
      token = signed_token("iss" => "https://evil.example")

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens for the wrong audience" do
      token = signed_token("aud" => "wrong-client")

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens for the wrong authorized party" do
      token = signed_token("azp" => "wrong-client")

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens missing the subject" do
      token = token_with_claims(claims.reject { |key, _| key == "sub" })

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens missing expiration" do
      token = token_with_claims(claims.reject { |key, _| key == "exp" })

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens missing issued-at time" do
      token = token_with_claims(claims.reject { |key, _| key == "iat" })

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens missing the nonce" do
      token = token_with_claims(claims.reject { |key, _| key == "nonce" })

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    it "rejects id tokens with the wrong nonce" do
      token = signed_token("nonce" => "wrong-nonce")

      expect { parse_id_token(token) }.to raise_error(OmniAuth::DoximityOauth2::JWTVerificationError)
    end

    def signed_token(overrides = {})
      token_with_claims(claims.merge(overrides))
    end

    def token_with_claims(token_claims)
      JWT.encode(token_claims, rsa_key, "RS256", kid: kid)
    end

    def parse_id_token(token)
      subject.send(:parse_id_token, token)
    end

    def base64url_uint(number)
      hex = number.to_i.to_s(16)
      hex = "0#{hex}" if hex.length.odd?
      Base64.urlsafe_encode64([hex].pack("H*")).delete("=")
    end
  end
end
