# frozen_string_literal: true

require 'cgi'
require 'excon'
require 'json'
require 'oga'
require 'securerandom'

module Fluminus
  # API provides an abstraction over the LumiNUS API
  class API
    API_BASE_URI = 'https://luminus.azure-api.net'
    OCM_APIM_SUBSCRIPTION_KEY = '6963c200ca9440de8fa1eede730d8f7e'

    def authenticate(username, password)
      if @jwt.nil?
        @jwt = Authentication.jwt(username, password)
      else
        true
      end
    end

    def authenticated?
      !@jwt.nil?
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
        api_data = api('/module/?populate=termdetail')['data']
        @modules = api_data.map { |a| Module.from_api(a) }
      else
        @modules
      end
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
  end
end
