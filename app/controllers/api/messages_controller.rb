class Api::MessagesController < ApplicationController
  # GET /api/messages/:channel_id/latest
  def latest
    begin
      # Find the slack channel
      slack_channel = SlackChannel.find_by(id: params[:channel_id])
      return render json: { isSuccess: false, error: "Channel not found" }, status: 404 unless slack_channel

      # Get recent activity from Slack API
      slack_client = Slack::Client.new(slack_channel.incident.organization)

      # Fetch recent messages (last 5)
      response = slack_client.conversations_history(
        channel: slack_channel.slack_channel_id,
        limit: 5
      )

      return render json: { isSuccess: false, error: "Failed to fetch messages" } unless response && response["ok"]

      messages = response["messages"] || []

      # Filter to human messages (no bots)
      human_messages = messages.select { |msg|
        msg["bot_profile"].blank? &&
        msg["user"].present? &&
        msg["text"].present? &&
        msg["text"].strip.length > 0
      }

       return render json: {
        isSuccess: true,
        latest: nil,
        author: nil
      } if human_messages.empty?

       # Get the most recent human message
       latest_message = human_messages.first

      # Try to get author info
      slack_user = slack_channel.incident.organization.slack_users
                                .find_by(slack_user_id: latest_message["user"])

      author_name = if slack_user&.display_name&.present?
                     slack_user.display_name
      elsif slack_user&.real_name&.present?
                     slack_user.real_name
      else
                     "Team Member"
      end

      author_avatar = slack_user&.avatar_url&.present? ? slack_user.avatar_url : "/avatar.svg"

      # For real Slack dates parse `ts` field: "1758841564.052399" into Unix epoch
      millis = latest_message["ts"]&.to_f

      # Show only messages from incident time forward to be relevant
      if millis
        incident_epoch = slack_channel.incident.declared_at.to_f rescue Time.current.to_f

        # Skip if too old
        if millis < incident_epoch
           return render json: {
            isSuccess: true,
            latest: nil,
            author: nil
          }
        end
      end

      render json: {
        isSuccess: true,
        latest: {
          text: latest_message["text"],
          timestamp: millis
        },
        author: {
          name: author_name,
          avatar: author_avatar
        }
      }

    rescue ActiveRecord::RecordNotFound
      render json: { isSuccess: false, error: "Channel not found" }, status: 404
    rescue => e
      Rails.logger.error("🔍 Messages endpoint error: #{e.class} - #{e.message}")
      render json: { isSuccess: false, error: "Server error" }, status: 500
    end
  end
end
