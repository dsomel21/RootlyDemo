class SlackChannel < ApplicationRecord
  belongs_to :incident

  validates :slack_channel_id, presence: true
  validates :name, presence: true
  validates :incident_id, uniqueness: true

  # Generate a Slack deep link to open this channel directly in the Slack app
  # Format: https://app.slack.com/client/{team_id}/{channel_id}
  def slack_deep_link
    team_id = incident.organization.slack_installation.team_id
    "https://app.slack.com/client/#{team_id}/#{slack_channel_id}"
  end

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

  ##
  # Fetches the latest human message from this Slack channel.
  # Returns a hash with message data and author information.
  #
  # === Returns
  #
  #   {
  #     author: "Jane Doe",
  #     avatar_url: "https://...",
  #     text: "Message content...",
  #     permalink: "https://slack.com/archives/...",
  #     ts: "1759034524.580159",
  #     sent_at: "2025-09-28T00:42:04-04:00"
  #   }
  #
  # === Returns nil if no human messages found
  def fetch_latest_message
    # Fetch recent messages from Slack channel
    messages = fetch_slack_history.first(20)

    # Filter out bot messages and find the latest human message
    human_messages = messages.reject { |msg| msg["bot_profile"].present? }
    latest_message = human_messages.first

    return nil unless latest_message

    # Get user info for the message author
    user_id = latest_message["user"]
    slack_user = incident.organization.slack_users.find_by(slack_user_id: user_id)

    # If we don't have the user, try to fetch their profile
    if slack_user.nil? && user_id.present?
      # Create a new SlackUser record and fetch their profile
      slack_user = incident.organization.slack_users.create!(slack_user_id: user_id)
      FetchSlackUserProfileJob.perform_later(incident.organization.id, user_id)
    end

    # Build the response data
    {
      author: determine_author_name(slack_user, user_id),
      avatar_url: slack_user&.avatar_url || "",
      text: latest_message["text"] || "",
      permalink: "https://slack.com/archives/#{slack_channel_id}/p#{latest_message['ts'].gsub('.', '')}",
      ts: latest_message["ts"],
      sent_at: Time.at(latest_message["ts"].to_f).iso8601
    }
  end

  private

  # Determines the best display name for a Slack user
  def determine_author_name(slack_user, user_id)
    return "Unknown User" if slack_user.nil?

    # Try different name fields in order of preference
    slack_user.display_name.presence ||
    slack_user.real_name.presence ||
    slack_user.title.presence ||
    user_id ||
    "Unknown User"
  end
end
