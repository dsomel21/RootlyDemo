module Slack
  module Workflows
    class ResolveIncidentCommand
      def initialize(organization:, params:)
        @organization = organization
        @params = params
        @channel_id = params[:channel_id]
        @user_id = params[:user_id]
        @client = Slack::Client.new(@organization)
      end

      def call
        find_incident_for_channel
        validate_can_resolve
        resolve_incident
        post_resolution_message
        enqueue_analytics_job
        build_success_response
      rescue => e
        Rails.logger.error "Failed to resolve incident: #{e.message}"
        build_error_response(e.message)
      end

      private

      attr_reader :organization, :params, :channel_id, :user_id, :client
      attr_accessor :incident, :slack_channel

      def find_incident_for_channel
        # Find the slack channel for this organization and channel ID
        @slack_channel = SlackChannel.joins(:incident)
                                   .where(slack_channel_id: channel_id)
                                   .where(incidents: { organization_id: organization.id })
                                   .first

        @incident = @slack_channel&.incident

        Rails.logger.info "Channel lookup: #{channel_id} -> #{@slack_channel&.name} -> Incident ##{@incident&.number}"
      end

      def validate_can_resolve
        unless incident
          # Not an incident channel - show available incident channels
          available_incidents = organization.incidents
                                          .joins(:slack_channel)
                                          .where.not(status: :resolved)
                                          .includes(:slack_channel, :slack_creator)
                                          .order(declared_at: :desc)
                                          .limit(10)

          if available_incidents.any?
            incident_list = available_incidents.map do |inc|
              "• <##{inc.slack_channel.slack_channel_id}> - ##{inc.number}: #{inc.title}"
            end.join("\n")

            raise ValidationError, "❌ This command only works in incident channels.\n\n🔍 *Active incident channels:*\n#{incident_list}"
          else
            raise ValidationError, "❌ This command only works in incident channels.\n\n✅ No active incidents found - great job! 🎉"
          end
        end

        if incident.resolved?
          resolved_time = time_ago_in_words(incident.resolved_at)
          raise ValidationError, "✅ This incident was already resolved #{resolved_time} ago!"
        end

        Rails.logger.info "Validation passed: Can resolve incident ##{incident.number}"
      end

      def resolve_incident
        @resolution_time = Time.current
        @duration = calculate_duration

        incident.update!(
          status: :resolved,
          resolved_at: @resolution_time
        )

        Rails.logger.info "✅ Resolved incident ##{incident.number} after #{@duration[:human]}"
      end

      def calculate_duration
        total_seconds = (@resolution_time - incident.declared_at).to_i

        hours = total_seconds / 3600
        minutes = (total_seconds % 3600) / 60
        seconds = total_seconds % 60

        human_readable = if hours > 0
          "#{hours}h #{minutes}m"
        elsif minutes > 0
          "#{minutes}m #{seconds}s"
        else
          "#{seconds}s"
        end

        {
          total_seconds: total_seconds,
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          human: human_readable
        }
      end

      def post_resolution_message
        message = build_resolution_message
        client.chat_post_message(message)
        Rails.logger.info "Posted resolution message for incident ##{incident.number}"
      end

      # 📌 TODO: Move these things into the app/presenters
      def build_resolution_message
        {
          channel: channel_id,
          text: "🎉 Incident ##{incident.number} has been resolved!",
          blocks: [
            {
              type: "header",
              text: {
                type: "plain_text",
                text: "🎉 Incident Resolved!"
              }
            },
            {
              type: "section",
              fields: [
                {
                  type: "mrkdwn",
                  text: "*Incident:*\n##{incident.number} - #{incident.title}"
                },
                {
                  type: "mrkdwn",
                  text: "*Severity:*\n#{incident.severity&.upcase || 'SEV2'}"
                },
                {
                  type: "mrkdwn",
                  text: "*Resolution Time:*\n#{@duration[:human]}"
                },
                {
                  type: "mrkdwn",
                  text: "*Resolved By:*\n<@#{user_id}>"
                },
                {
                  type: "mrkdwn",
                  text: "*Declared:*\n<!date^#{incident.declared_at.to_i}^{date_short_pretty} {time}|#{incident.declared_at}>"
                },
                {
                  type: "mrkdwn",
                  text: "*Resolved:*\n<!date^#{@resolution_time.to_i}^{date_short_pretty} {time}|#{@resolution_time}>"
                }
              ]
            },
            build_stats_section,
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: "✅ *Status:* Resolved\n📊 Great work team! This channel will remain available for post-incident discussion."
              }
            }
          ].compact
        }
      end

      def build_stats_section
        # Add some fun stats if resolution was quick
        if @duration[:total_seconds] < 300 # Less than 5 minutes
          emoji = "⚡"
          message = "Lightning fast resolution!"
        elsif @duration[:total_seconds] < 1800 # Less than 30 minutes
          emoji = "🚀"
          message = "Quick resolution!"
        elsif @duration[:total_seconds] < 3600 # Less than 1 hour
          emoji = "👍"
          message = "Good response time!"
        else
          emoji = "💪"
          message = "Thanks for seeing this through!"
        end

        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "#{emoji} #{message} • Total time: #{@duration[:human]}"
            }
          ]
        }
      end

      def enqueue_analytics_job
        Rails.logger.info "📊 Enqueuing incident analytics job for ##{incident.number}"
        GatherIncidentAnalyticsJob.perform_later(incident.id)
      end

      def build_success_response
        Slack::Response.ok({
          response_type: "ephemeral",
          text: "✅ Incident ##{incident.number} has been resolved!"
        })
      end

      def build_error_response(error_message)
        Slack::Response.ok({
          response_type: "ephemeral",
          text: error_message
        })
      end

      def time_ago_in_words(time)
        seconds = (Time.current - time).to_i

        case seconds
        when 0..59
          "#{seconds} seconds"
        when 60..3599
          "#{seconds / 60} minutes"
        when 3600..86399
          "#{seconds / 3600} hours"
        else
          "#{seconds / 86400} days"
        end
      end

      class ValidationError < StandardError; end
    end
  end
end
