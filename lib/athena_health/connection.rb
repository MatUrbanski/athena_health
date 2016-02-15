require 'json'
require 'pry'

module AthenaHealth
  class Connection
    BASE_URL    = 'https://api.athenahealth.com'.freeze
    AUTH_PATH   = { 'v1' => 'oauth', 'preview1' => 'oauthpreview', 'openpreview1' => 'oauthopenpreview' }

    attr_reader :token

    def initialize(version:, key:, secret:)
      @version = version
      @key = key
      @secret = secret
    end

    def authenticate
      response = Typhoeus.post(
        "#{BASE_URL}/#{AUTH_PATH[@version]}/token",
        userpwd: "#{@key}:#{@secret}",
        body: { grant_type: 'client_credentials' }
      ).response_body

      @token = JSON.parse(response)['access_token']
    end

    def call(endpoint:, method:, second_call: false)
      authenticate if @token.nil?

      request = Typhoeus::Request.new(
        "#{BASE_URL}/#{@version}/#{endpoint}",
        method: method,
        headers: { Authorization: "Bearer #{@token}"}
      ).run

      if request.response_code == 401 && !second_call
        authenticate
        call(endpoint: endpoint, method: method, second_call: true)
      end

      AthenaHealth::Error.new(code: request.response_code).render if request.response_code != 200

      JSON.parse(request.response_body)
    end
  end
end
