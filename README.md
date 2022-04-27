# Omniauth::DoximityOauth2

OmniAuth strategy for Doximity.

Sign up for Doximity's API to get your OAuth credentials at: https://www.doximity.com/developers/api_signup

For more details on what tools we have available, read our developer docs: https://www.doximity.com/developers/documentation

## Installation

Add to your `Gemfile`:

```ruby
gem 'omniauth-doximity-oauth2'
```

Then `bundle install`.

## Usage

Here's an example for adding the middleware to a Rails app in `config/initializers/omniauth.rb`:

```ruby
DOXIMITY_OMNIAUTH_SETUP = lambda do |env|
  env['omniauth.strategy'].options[:client_id] = ENV["DOXIMITY_CLIENT_ID"]
  env['omniauth.strategy'].options[:client_secret] = ENV["DOXIMITY_CLIENT_SECRET"]
  env['omniauth.strategy'].options[:scope] = "openid profile:read:basic profile:read:email"
end

Rails.application.config.middleware.use OmniAuth::Builder do
  configure do |config|
    config.path_prefix = '/auth'
  end
  provider :doximity_oauth2, setup: DOXIMITY_OMNIAUTH_SETUP
end
```

Talk with the Doximity API team about what scopes you need for your application, and make sure to edit your OmniAuth initializer to request them.

Update your `config/routes.rb` to support Doximity OmniAuth callbacks on your session controller:

```ruby
Rails.application.routes.draw do
  get "/omniauth/:provider/callback" => "sessions#create"
  post "/signout" => "sessions#destroy"
  get "/omniauth/failure" => "sessions#failure"
end
```

Then, create a sign-in button that posts to `/auth/doximity`. Use one of the Sign in with Doximity logos, available here: https://www.doximity.com/developers/documentation#logos-for-use-by-third-party-developers

```ruby
<%= link_to "Sign in with Doximity", "/auth/doximity", method: :post do %>
  <%= image_tag "https://assets.doxcdn.com/image/upload/v1/apps/doximity/api/api-button-sign-in-with-doximity.png", alt: "Sign in with Doximity button"%>
<% end %>
```

Note that in OmniAuth versions 2 and above, links to sign in should use the POST method. Read more [here](https://github.com/omniauth/omniauth/wiki/Resolving-CVE-2015-9284)

In your callback controller, you will have a few resources available to you after the user approves your application and logs in.

```ruby
class SessionsController < ApplicationController
  def create
    session[:user_uuid] = request.env["omniauth.auth"]["uid"]
    redirect_to request.env["omniauth.origin"] || "/", :notice => "Signed in!"
  end

  def destroy
    session.delete(:user_uuid)
    redirect_to "/"
  end

  def failure
    redirect_to request.env["omniauth.origin"] || "/", :alert => "Authentication error: #{params[:message].humanize}"
  end
end
```

You can also add an `origin` param to your `/auth/doximity` post, which will be provided in the `request.env["omniauth.origin"]` variable after the success or failure callback.

## Configuration

You can configure several options, inside the configuration lambda:

* `[:scope]`: A comma-separated list of permissions you want to request from the user.Caveats:
  * The `openid` scope is suggested. Alternatively, if the `openid` scope is not requested `omniauth-doximity` will make an additional request to retrieve information about the signed in user using your other scopes. Your app may be subject to rate limiting depending on your usage.
  * Without any scopes, you will still be able to log in the user and retrieve a unique UUIDv4 to distinguish them from other users.

* `[:name]`: The name of the strategy. The default name is `doximity_oauth2` but it can be changed to any string. The `:provider` part of OmniAuth  URLs will also change to `/auth/{{ name }}`.

* `[:client_options][:site]`: Override the Doximity OAuth provider website. You may be provided with a development site to use while setting up your integration, which you would set here.

* `[:pkce]`: A boolean denoting whether to follow the PKCE OAuth spec. Default `true`. Note that if set to false, your OmniAuth credentials hash will not include a `refresh` token. Your OAuth application also may require PKCE to use OmniAuth.

## Auth Hash

Here's an example of an authentication hash available in the callback by accessing `request.env['omniauth.auth']`:

```ruby
{
  "provider" => "doximity",
  "uid" => "cc485bd2-b25a-4677-b05c-e98febf7789d",
  "info" => {
    "name" => "Test User",
    "given_name" => "Test",
    "family_name" => "User",
    "primary_email" => "md@doximity.com",
    "emails" => ["md@doximity.com"],
    "profile_photo_url" => "http://res.cloudinary.com/doximity-development/image/upload/l_text:Helvetica_130_bold:AT,co_rgb:FFFFFF,t_profile_photo_320x320/profile-placeholder-registered-5.jpg",
    "credentials" => "Other",
    "specialty" => "Optometrist"
  },
  "credentials" => {
    "token" => "gMej-ecC9Wzy4KkUCypYQ1J_8mQ1Yo9RXJYwU2kCyPKciuuOIxHflFlLP0PLlJmwnjPwlNa7nkQeeOcz-zyC6w==",
    "refresh_token" => "go-40T6xPOzSOd09NTElQ0tGi-BU5hluljET8wa3syzxBqsG5BP0PJW_CsbDhmm49T081jhsIMnP-OQG8McYYPdOENc027K87gGSurOquANzx8qlo4hTJ903LNGpTZ6VcV1Ci0jomvJdH1NsCq5nLxeCy4dBctTZEMA-c3pOVZ0=",
    "expires_at" => 1650335410,
    "expires" => true,
    "access_token" => "gMej-ecC9Wzy4KkUCypYQ1J_8mQ1Yo9RXJYwU2kCyPKciuuOIxHflFlLP0PLlJmwnjPwlNa7nkQeeOcz-zyC6w==",
    "scope" => "profile:read:email profile:read:basic openid",
    "token_type" => "bearer"
  }, "extra" => {
    "raw_subject_info" => {
      "acr" => 2, "at_hash" => "uVfpy56HzI3J_dZR2kyxrQ", "aud" => ["https://auth.doximity.com", "6bd7e37e80fd06819ca13b268adea5fbe57446a9f9e1982f9483813d7272acf1"], "auth_time" => 1650333376, "azp" => "6bd7e37e80fd06819ca13b268adea5fbe57446a9f9e1982f9483813d7272acf1", "credentials" => "Other", "emails" => ["md@doximity.com"], "exp" => 1650335384, "family_name" => "User", "given_name" => "Test", "iat" => 1650333610, "iss" => "https://auth.doximity.com", "name" => "Test User", "primary_email" => "md@doximity.com", "profile_photo_url" => "http://res.cloudinary.com/doximity-development/image/upload/l_text:Helvetica_130_bold:AT,co_rgb:FFFFFF,t_profile_photo_320x320/profile-placeholder-registered-5.jpg", "sid" => "9", "specialty" => "Optometrist", "sub" => "cc485bd2-b25a-4677-b05c-e98febf7789d"
    }, "raw_credential_info" => {
      "token_type" => "bearer", "scope" => "profile:read:email profile:read:basic openid", "id_token" => "{{JWT omitted for brevity}}", "access_token" => "gMej-ecC9Wzy4KkUCypYQ1J_8mQ1Yo9RXJYwU2kCyPKciuuOIxHflFlLP0PLlJmwnjPwlNa7nkQeeOcz-zyC6w==", "refresh_token" => "go-40T6xPOzSOd09NTElQ0tGi-BU5hluljET8wa3syzxBqsG5BP0PJW_CsbDhmm49T081jhsIMnP-OQG8McYYPdOENc027K87gGSurOquANzx8qlo4hTJ903LNGpTZ6VcV1Ci0jomvJdH1NsCq5nLxeCy4dBctTZEMA-c3pOVZ0=", "expires_at" => 1650335410
    }
  }
}
```

## License

Licensed under Apache-2.0, see [LICENSE.txt](./LICENSE.txt)
