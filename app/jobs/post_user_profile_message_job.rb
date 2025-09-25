# Sidekiq Job: Posts rich profile message with user avatar to incident channel.
# Runs after profile data is available to personalize incident channels.
# Retries up to 2 times on failure.

class PostUserProfileMessageJob < ApplicationJob
  queue_as :default

  # Sidekiq-specific retry configuration
  sidekiq_options retry: 2, backtrace: true

  def perform(incident_id, slack_user_id)
    Rails.logger.info "📸 Posting user profile message for incident #{incident_id}, user #{slack_user_id}"

    # Find the incident and related data
    incident = Incident.find(incident_id)
    slack_user = incident.organization.slack_users.find_by(slack_user_id: slack_user_id)

    unless incident.slack_channel
      Rails.logger.warn "❌ No Slack channel found for incident #{incident_id}"
      return
    end

    unless slack_user
      Rails.logger.warn "❌ SlackUser #{slack_user_id} not found for incident #{incident_id}"
      return
    end

    # Only post if we have meaningful profile data
    unless slack_user.avatar_url.present? || slack_user.real_name.present?
      Rails.logger.info "ℹ️ No profile data available for #{slack_user_id}, skipping profile message"
      return
    end

    begin
      # Build and send the profile message
      client = Slack::Client.new(incident.organization)
      message_payload = build_profile_message(incident, slack_user)

      response = client.chat_post_message(message_payload)

      Rails.logger.info "✅ Posted profile message for #{slack_user.display_name || slack_user.real_name || slack_user_id}"
      Rails.logger.info "   Channel: ##{incident.slack_channel.name}"
      Rails.logger.info "   Avatar: #{slack_user.avatar_url ? 'Included' : 'None'}"

    rescue => e
      Rails.logger.error "❌ Failed to post profile message: #{e.message}"
      Rails.logger.error "   Incident: #{incident_id} (#{incident.title})"
      Rails.logger.error "   User: #{slack_user_id}"

      # Re-raise to trigger Sidekiq retry logic for temporary failures
      raise e
    end
  end

  private

  # Build a rich Block Kit message showcasing the user's profile
  def build_profile_message(incident, slack_user)
    {
      channel: incident.slack_channel.slack_channel_id,
      text: "🔥 Incident COMMANDER: #{format_user_name(slack_user)} 🔥",
      blocks: [
        build_profile_header_block(slack_user),
        build_profile_details_block(slack_user, incident)
      ].compact
    }
  end

  # Header block with user's avatar and name
  def build_profile_header_block(slack_user)
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: "*🔥 INCIDENT COMMANDER 🔥*"
      },
      accessory: slack_user.avatar_url.present? ? {
        type: "image",
        image_url: slack_user.avatar_url,
        alt_text: "#{format_user_name(slack_user)}'s profile picture"
      } : nil
    }
  end

  # Details block with user information
  def build_profile_details_block(slack_user, incident)
    fields = []

    # Add name field
    if slack_user.real_name.present?
      fields << {
        type: "mrkdwn",
        text: "*Name:*\n#{slack_user.real_name}"
      }
    end

    # Add email field
    if slack_user.email.present?
      fields << {
        type: "mrkdwn",
        text: "*Email:*\n#{slack_user.email}"
      }
    end

    # Add title field
    if slack_user.title.present?
      fields << {
        type: "mrkdwn",
        text: "*Title:*\n#{slack_user.title}"
      }
    end

    # Add incident context
    fields << {
      type: "mrkdwn",
      text: "*Declared:*\n<!date^#{incident.declared_at.to_i}^{date_short_pretty} {time}|#{incident.declared_at}>"
    }

    return nil if fields.empty?

    {
      type: "section",
      fields: fields
    }
  end

  # Format user name with fallbacks
  def format_user_name(slack_user)
    slack_user.display_name.presence ||
    slack_user.real_name.presence ||
    "<@#{slack_user.slack_user_id}>"
  end
end
