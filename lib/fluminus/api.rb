require 'cgi'
require 'excon'
require 'json'
require 'oga'
require 'securerandom'

module Fluminus
  class API
    AUTH_BASE_URI = 'https://luminus.nus.edu.sg'.freeze
    DISCOVERY_PATH = '/v2/auth/.well-known/openid-configuration'.freeze
    CLIENT_ID = 'verso'.freeze
    SCOPE = 'profile email role openid lms.read calendar.read lms.delete ' \
            'lms.write calendar.write gradebook.write offline_access'.freeze
    RESPONSE_TYPE = 'id_token token code'.freeze
    REDIRECT_URI = 'https://luminus.nus.edu.sg/auth/callback'.freeze

    API_BASE_URI = 'https://luminus.azure-api.net'.freeze
    OCM_APIM_SUBSCRIPTION_KEY = '6963c200ca9440de8fa1eede730d8f7e'.freeze

    def authenticate(username, password)
      authorization = oidc_authorization
      body = { username: username, password: password }
             .merge(authorization[:xsrf])

      response = Excon.post(authorization[:login_uri],
                            body: URI.encode_www_form(body),
                            headers: authorization[:headers])
      return unless response.status == 302

      callback_response =
        Excon.get(response.headers['location'],
                  headers: { cookie: response.headers['set-cookie'] })

      @jwt = form_jwt(callback_response)
      true
    end

    def name
      if @name.nil?
        @name = api('/user/Profile')['userNameOriginal']
                .split.map(&:capitalize).join(' ')
      else
        @name
      end
    end

    def modules(opts = {})
      if opts[:force_fetch] || @modules.nil?
        @modules = api("/module/?populate=#{URI.encode('termdetail')}")['data']
      else
        @modules
      end
    end

    def modules_taking(opts = {})
      modules(opts).filter { |m| !m['access']['access_Create'] }
    end

    def modules_teaching(opts = {})
      modules(opts).filter { |m| m['access']['access_Create'] }
    end

    private

    def api(path)
      uri = form_api_uri(path)
      headers = { 'Authorization' => "Bearer #{@jwt}",
                  'Ocp-Apim-Subscription-Key' => OCM_APIM_SUBSCRIPTION_KEY,
                  'Content-Type': 'application/json' }
      response = Excon.get(uri, headers: headers)
      return unless response.status == 200

      JSON.parse(response.body)
    end

    def form_api_uri(path)
      URI.join(API_BASE_URI, path).to_s
    end

    def form_jwt(response)
      fragment = URI(response.headers['location']).fragment
      decoded = Hash[URI.decode_www_form(fragment)]
      decoded['id_token']
    end

    def form_auth_uri(path)
      URI.join(AUTH_BASE_URI, path).to_s
    end

    def oidc_authorization
      first_response = oidc_first_request
      return unless first_response.status == 302

      second_response = oidc_second_request(first_response)
      return unless second_response.status == 200

      form_oidc_authorization_from_responses(first_response, second_response)
    end

    def form_oidc_authorization_from_responses(first_response, second_response)
      second_parsed = parse_second_response(second_response)

      cookies = oidc_cookies_from_responses(first_response, second_response)

      { login_uri: form_auth_uri(second_parsed['loginUrl']),
        headers: { 'Cookie' => cookies,
                   'Content-Type' => 'application/x-www-form-urlencoded' },
        xsrf: { second_parsed['antiForgery']['name'] =>
                second_parsed['antiForgery']['value'] } }
    end

    def parse_second_response(second_response)
      second_response_body = Oga.parse_html(second_response.body)
                                .css('#modelJson').text.strip
      second_unescaped = CGI.unescape_html(second_response_body)
      JSON.parse(second_unescaped)
    end

    def oidc_cookies_from_responses(first_response, second_response)
      [first_response, second_response]
        .map { |r| r.headers['set-cookie'].split(';').first }.join(';')
    end

    def oidc_first_request
      first_uri = auth_endpoint_uri(auth_payload)
      Excon.get(first_uri)
    end

    def oidc_second_request(first_response)
      second_uri = first_response.headers['location']
      Excon.get(second_uri,
                headers: { cookie: first_response.headers['set-cookie'] })
    end

    def auth_payload
      state = SecureRandom.hex(16)
      nonce = SecureRandom.hex(16)
      { client_id: CLIENT_ID, scope: SCOPE, response_type: RESPONSE_TYPE,
        redirect_uri: REDIRECT_URI, state: state, nonce: nonce }
    end

    def auth_endpoint_uri(payload)
      discovery_uri = form_auth_uri(DISCOVERY_PATH)
      discovery_response = Excon.get(discovery_uri.to_s)
      discovery_parsed = JSON.parse(discovery_response.body)
      uri = URI(discovery_parsed['authorization_endpoint'])
      uri.query = URI.encode_www_form(payload).gsub('+', '%20')
      uri.to_s
    end
  end
end
