# Sidekiq Job: Updates Slack channel metadata (topic, description, pins)
# Runs asynchronously to set channel topic, pin incident link, and update description
# Retries up to 3 times on failure.

class UpdateSlackChannelMetadataJob < ApplicationJob
  queue_as :default

  # Sidekiq-specific retry configuration
  sidekiq_options retry: 3, backtrace: true

  def perform(incident_id)
    Rails.logger.info "📋 Updating Slack channel metadata for incident #{incident_id}"

    # Find the incident and related data
    incident = Incident.find(incident_id)

    unless incident.slack_channel
      Rails.logger.warn "❌ No Slack channel found for incident #{incident_id}"
      return
    end

    begin
      client = Slack::Client.new(incident.organization)
      channel_id = incident.slack_channel.slack_channel_id

      # Update channel topic
      update_channel_topic(client, channel_id, incident)

      # Pin incident link
      pin_incident_link(client, channel_id, incident)

      # TODO: Update channel description (enhance with AI later
      # - Could summarize incident details automatically
      # - Could highlight key stakeholder info
      # - Could reference related systems/services
      # update_channel_description(client, channel_id, incident)

      Rails.logger.info "✅ Updated Slack channel metadata for incident ##{incident.number}"

    rescue => e
      Rails.logger.error "❌ Failed to update Slack channel metadata: #{e.message}"
      Rails.logger.error "   Incident: #{incident_id} (#{incident.title})"

      # Re-raise to trigger Sidekiq retry logic for temporary failures
      raise e
    end
  end

  private

  def update_channel_topic(client, channel_id, incident)
    topic = build_channel_topic(incident)

    client.conversations_set_topic({
      channel: channel_id,
      topic: topic
    })

    Rails.logger.info "📋 Updated channel topic: #{topic}"
  end

  def pin_incident_link(client, channel_id, incident)
    # Use the new slug-based URL format for better readability
    slug = incident.slug
    base_url = Rails.env.production? ? "https://#{ENV['HOST']}" : "http://localhost:3000"
    incident_url = "#{base_url}/incidents/#{slug}"

    # Post a message to pin
    message_response = client.chat_post_message({
      channel: channel_id,
      text: "🔗 Incident Link: #{incident_url}",
      unfurl_links: false,
      unfurl_media: false
    })

    # Pin the message immediately
    if message_response["ok"]
      client.pins_add({
        channel: channel_id,
        timestamp: message_response.dig("message", "ts")
      })
      Rails.logger.info "📌 Pinned incident link to channel"
    end

  rescue => e
    Rails.logger.warn "Failed to pin incident link: #{e.message}"
  end

  # Build channel topic with emoji and status
  def build_channel_topic(incident)
    severity_emoji = severity_to_emoji(incident.severity)
    status_text = incident.status.to_s.upcase
    "#{severity_emoji} #{incident.severity&.upcase || 'SEV-2'} #{status_text}"
  end

  def severity_to_emoji(severity)
    case severity.to_s
    when "sev0"
      ":red_circle:"
    when "sev1"
      ":large_orange_circle:"
    when "sev2"
      ":large_yellow_circle:"
    else
      ":large_yellow_circle:"
    end
  end

  # TODO: Future channel description (could be enhanced with AI)
  def update_channel_description(client, channel_id, incident)
    description = "🚨 Incident ##{incident.number}: #{incident.title}"

    if incident.description.present?
      description += "\n\n#{incident.description}"
    end

    client.conversations_set_purpose({
      channel: channel_id,
      purpose: description
    })
  end
end
