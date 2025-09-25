module Slack
  module Workflows
    class CreateIncidentInteraction
      def initialize(organization:, payload:)
        @organization = organization
        @payload = payload
        @client = Slack::Client.new(@organization)
      end

      def call
        extract_form_data
        validate_incident_data
        ActiveRecord::Base.transaction do
          find_or_create_slack_user
          generate_incident_number
          create_incident_record
          create_dedicated_slack_channel
          link_incident_to_slack_channel
          invite_creator_to_channel
          post_welcome_message_to_channel
        end
        build_success_response
      rescue => e
        Rails.logger.error "Failed to create incident: #{e.message}"
        build_error_response(e.message)
      end

      private

      attr_reader :organization, :payload, :client
      attr_accessor :title, :description, :severity, :slack_user_id, :incident

      def extract_form_data
        values = payload.dig("view", "state", "values") || {}

        @title = values.dig("title_block", "title_input", "value")
        @description = values.dig("description_block", "description_input", "value")
        @severity = values.dig("severity_block", "severity_select", "selected_option", "value") || "sev2"
        @slack_user_id = payload.dig("user", "id")

        Rails.logger.info "Extracted incident data: title='#{title}', severity=#{severity}, user=#{slack_user_id}"
      end

      def validate_incident_data
        if title.blank?
          raise ValidationError, "Title cannot be empty"
        end

        if title.length > 100
          raise ValidationError, "Title must be less than 100 characters"
        end

        Rails.logger.info "Incident data validation passed"
      end

      def find_or_create_slack_user
        @slack_user = organization.slack_users.find_or_initialize_by(slack_user_id: slack_user_id)

        if @slack_user.new_record? || @slack_user.display_name.blank?
          fetch_and_update_user_profile
        end

        @slack_user.save! if @slack_user.changed?
        Rails.logger.info "Found/created Slack user: #{@slack_user.display_name || @slack_user.real_name || slack_user_id}"
      end

      def fetch_and_update_user_profile
        user_info = client.users_info(slack_user_id)
        profile = user_info.dig("user", "profile") || {}
        user_data = user_info["user"] || {}

        @slack_user.assign_attributes(
          display_name: profile["display_name"],
          real_name: user_data["real_name"],
          avatar_url: profile["image_192"] || profile["image_72"],
          email: profile["email"],
          title: profile["title"]
        )
      rescue => e
        Rails.logger.warn "Failed to fetch user profile for #{slack_user_id}: #{e.message}"
        # Continue without profile data
      end

      def generate_incident_number
        @incident_number = IncidentCounter.next_number_for_organization(organization)
        Rails.logger.info "Generated incident number: #{@incident_number}"
      end

      def create_incident_record
        @incident = organization.incidents.create!(
          title: title,
          description: description,
          severity: severity,
          number: @incident_number,
          slack_creator: @slack_user,
          declared_at: Time.current,
          status: :investigating
        )
        Rails.logger.info "Created incident record with ID: #{incident.id}"
      end

      def create_dedicated_slack_channel
        channel_name = generate_channel_name

        @slack_channel_response = client.conversations_create({
          name: channel_name,
          is_private: false
        })
        Rails.logger.info "E: #{@slack_channel_response.dig('channel', 'name')}"
      end

      def generate_channel_name
        "inc-#{@incident_number.to_s.rjust(4, '0')}-#{title.parameterize}"
      end

      def link_incident_to_slack_channel
        incident.create_slack_channel!(
          slack_channel_id: @slack_channel_response.dig("channel", "id"),
          name: @slack_channel_response.dig("channel", "name")
        )
        Rails.logger.info "Linked incident to Slack channel"
      end

      def invite_creator_to_channel
        channel_id = @slack_channel_response.dig("channel", "id")

        client.conversations_invite({
          channel: channel_id,
          users: slack_user_id
        })

        Rails.logger.info "Invited creator #{slack_user_id} to incident channel"
      rescue => e
        # Don't fail the entire incident creation if invite fails
        Rails.logger.warn "Failed to invite creator to channel: #{e.message}"
      end

      def post_welcome_message_to_channel
        message = build_welcome_message
        client.chat_post_message(message)
        Rails.logger.info "Posted welcome message to incident channel"
      end

      def build_welcome_message
        {
          channel: incident.slack_channel.slack_channel_id,
          text: "🚨 *Incident ##{incident.number}* has been declared",
          blocks: [
            build_header_block,
            build_details_block,
            build_description_block
          ].compact
        }
      end

      # 📌 TODO: Move these things into the app/presenters
      def build_header_block
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🚨 Incident ##{incident.number}"
          }
        }
      end

      # 📌 TODO: Move these things into the app/presenters
      def build_details_block
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*Title:*\n#{incident.title}"
            },
            {
              type: "mrkdwn",
              text: "*Severity:*\n#{incident.severity&.upcase || 'SEV2'}"
            },
            {
              type: "mrkdwn",
              text: "*Status:*\n#{incident.status.capitalize}"
            },
            {
              type: "mrkdwn",
              text: "*Declared:*\n<!date^#{incident.declared_at.to_i}^{date_short_pretty} {time}|#{incident.declared_at}>"
            },
            {
              type: "mrkdwn",
              text: "*Declared by:*\n#{format_user_name(@slack_user)}"
            }
          ]
        }
      end

      def build_description_block
        return nil if incident.description.blank?

        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Description:*\n#{incident.description}"
          }
        }
      end

      def format_user_name(slack_user)
        return "Unknown User" unless slack_user

        slack_user.display_name.presence ||
        slack_user.real_name.presence ||
        "<@#{slack_user.slack_user_id}>"
      end

      def build_success_response
        Slack::Response.ok({ response_action: "clear" })
      end

      def build_error_response(error_message)
        if error_message.include?("Title")
          # User validation error - show specific field error in modal
          Slack::Response.new({
            response_action: "errors",
            errors: {
              title_block: error_message
            }
          }, status: 200, ok: false)
        else
          # Internal server error - intentionally show generic message to user
          # This prevents exposing technical details while indicating it's not their fault
          Slack::Response.new({
            response_action: "errors",
            errors: {
              title_block: "⚠️ Internal server error. This isn't your fault - please try again or contact support."
            }
          }, status: 200, ok: false)
        end
      end

      class ValidationError < StandardError; end
    end
  end
end
