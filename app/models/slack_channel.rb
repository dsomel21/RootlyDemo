class SlackChannel < ApplicationRecord
  belongs_to :incident

  validates :slack_channel_id, presence: true
  validates :name, presence: true
  validates :incident_id, uniqueness: true

  ##
  # Fetches the entire message history for this channel via the Slack API.
  # This method may perform multiple HTTP requests if the message history is paginated.
  #
  # === Example
  #
  #   [
  #     {
  #       "user" => "U09GY1KKMK4",
  #       "type" => "message",
  #       "ts" => "1758841564.052399",
  #       "client_msg_id" => "9447023c-0273-4237-969e-1a7446f6402a",
  #       "text" => "This is amazing :fire:",
  #       "team" => "T09GY1KKMFC",
  #       "blocks" => [ { ... } ] # Slack message blocks (condensed)
  #     },
  #     {...}
  #   ]
  #
  # === Usage
  #
  #   @slack_channel.fetch_slack_history # => Array of Slack messages
  def fetch_slack_history
    client = Slack::Client.new(self.incident.organization)
    all_messages = []
    cursor = nil

    # Fetch the history in chunks of 100 messages to avoid rate limiting
    loop do
      response = client.conversations_history({
        channel: slack_channel_id,
        limit: 100,
        cursor: cursor
      }.compact)

      messages = response["messages"] || []
      all_messages.concat(messages)

      cursor = response.dig("response_metadata", "next_cursor")
      break if cursor.blank?

      sleep(0.1)
    end

    all_messages
  end
end
