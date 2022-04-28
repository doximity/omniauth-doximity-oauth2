# frozen_string_literal: true

require "spec_helper"
require "json"
require "omniauth-doximity-oauth2"
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
    end
  end
end
