Changelog
=========

## 1.5.0 - 10/24/2023
  * Add "login_hint" as an authorization option

## 1.4.0 - 10/24/2023
  * Support sending "callback_query_params" through the request phase, which will be treated as additional state params.

## 1.3.0 - 08/09/2023
  * Handle 'theme' parameter to be passed along to the OAuth authorization

## 1.2.0 - 05/05/2023
  * Update mechanism for verifying RSA public keys to work on OpenSSL 3
  * Ensure state persists between initial call and on callback

## 1.1.0 - 06/13/2022
  * Add "prompt" parameter to be persisted on request, allowing for silent authentication (among other things)

## 1.0.0 - 05/02/2022
  * Gem now publishes to RubyGems

## 0.2.0 - 04/27/2022
  * Change gem name

## 0.1.1 - 04/18/2022
  * Use Faraday and MultiJson
  * Update [README.md]("./README.md")

## 0.1.0 - 04/14/2022
  * Unlock omniauth-oauth2 dependency

## 0.0.1 - 03/31/2022
  * Initialize gem
