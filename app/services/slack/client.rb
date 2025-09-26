require "net/http"
require "uri"

module Slack
  class Client
    BASE = "https://slack.com/api".freeze

    def initialize(organization)
      @token = organization.slack_installation.bot_access_token_ciphertext
    end

    # Open a modal view
    def views_open(payload) = post("views.open", payload)

    # Create a new Slack channel
    def conversations_create(payload) = post("conversations.create", payload)

    # Invite users to a channel
    def conversations_invite(payload) = post("conversations.invite", payload)

    # Post a message to a channel
    def chat_post_message(payload) = post("chat.postMessage", payload)

    # Get user information (profile, name, etc.)
    def users_info(user_id) = post("users.info", { user: user_id })

    # List all users in the workspace
    def users_list(limit: 100) = post("users.list", { limit: limit })

    # Get conversation history from a channel (includes bot messages, "X Joined the channel", )
    # NOTE: This is not limited to only Messages. It will include transactional information like:
    # - "X Joined the channel"
    # - "X left the channel"
    # - "set the channel topic: :large_yellow_circle: SEV2 INVESTIGATING"
    def conversations_history(payload) = post("conversations.history", payload)

    # Set channel topic
    def conversations_setTopic(payload) = post("conversations.setTopic", payload)

    # Set channel purpose/description
    def conversations_setPurpose(payload) = post("conversations.setPurpose", payload)

    # Pin a message to channel
    def pins_add(payload) = post("pins.add", payload)

    private

    def post(path, payload)
      uri = URI("#{BASE}/#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@token}"
      req["Content-Type"]  = "application/json"
      req.body = payload.to_json

      res = http.request(req)
      body = JSON.parse(res.body)

      unless body["ok"]
        error_msg = body["error"] || "unknown_slack_error"
        Rails.logger.error "Slack API error: #{error_msg} for #{path}"
        raise "Slack API error: #{error_msg}"
      end

      body
    end
  end
end
