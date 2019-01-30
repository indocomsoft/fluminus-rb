module Fluminus
  class Authentication
    AUTH_BASE_URI = 'https://luminus.nus.edu.sg'.freeze
    DISCOVERY_PATH = '/v2/auth/.well-known/openid-configuration'.freeze
    CLIENT_ID = 'verso'.freeze
    SCOPE = 'profile email role openid lms.read calendar.read lms.delete ' \
            'lms.write calendar.write gradebook.write offline_access'.freeze
    RESPONSE_TYPE = 'id_token token code'.freeze
    REDIRECT_URI = 'https://luminus.nus.edu.sg/auth/callback'.freeze

    # Prevent class instantiation
    private_class_method :new

    class << self
      def jwt(username, password)
        authorization = oidc_authorization
        body = form_jwt_request_body(username, password, authorization[:xsrf])

        response = Excon.post(authorization[:login_uri],
                              body: body, headers: authorization[:headers])
        return unless response.status == 302

        callback_response =
          Excon.get(response.headers['location'],
                    headers: { cookie: response.headers['set-cookie'] })

        form_jwt(callback_response)
      end

      private

      def form_jwt_request_body(username, password, xsrf)
        body = { username: username, password: password }.merge(xsrf)
        URI.encode_www_form(body)
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

        form_oidc_authorization(first_response, second_response)
      end

      def form_oidc_authorization(first_response, second_response)
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
end
