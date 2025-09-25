require "net/http"
require "uri"
module Slack
  class Client
    BASE = "https://slack.com/api".freeze
    def initialize(organization)
      @token = organization.slack_installation.bot_access_token_ciphertext
    end
    def views_open(payload) = post("views.open", payload)

    private
    def post(path, payload)
      uri = URI("#{BASE}/#{path}")
      http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@token}"
      req["Content-Type"]  = "application/json"
      req.body = payload.to_json
      res  = http.request(req)
      body = JSON.parse(res.body)
      raise(body["error"] || "slack_error") unless body["ok"]
      body
    end
  end
end
