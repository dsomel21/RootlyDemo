module Slack
  module Workflows
    class DeclareCommand
      def call(organization:, params:)
        ctx = { org: organization, params: params }

        return Slack::Response.err("Usage: `/rootly declare <title>`") unless get_args(ctx)
        return Slack::Response.err("Could not build modal.")           unless build_modal(ctx)
        return Slack::Response.err("Slack error opening modal.")        unless tell_slack_to_open_modal(ctx)

        Slack::Response.ok({})
      end

      # Originally, I was thinking this could be used like:
      # @declare_command = Slack::Workflows::DeclareCommand.new(org, params)
      # @declare_command.get_args
      # @declare_command.build_modal
      # @declare_command.tell_slack_to_open_modal
      # This way, in the controller action, we can see what's happening, but I decided to just leave it all in this Worfkflow

      private

      # 1) Parse inputs from Slack payload
      def get_args(ctx)
        text = ctx[:params][:text].to_s.strip
        return false unless text =~ /^declare\s+(.+)/i
        ctx[:title]      = Regexp.last_match(1).strip
        ctx[:trigger_id] = ctx[:params][:trigger_id]
        ctx[:user_id]    = ctx[:params][:user_id]
        ctx[:title].present? && ctx[:trigger_id].present?
      end

      # 2) Build the modal JSON
      def build_modal(ctx)
        ctx[:modal] = BlockKits::DeclareModal.build(
          title: ctx[:title],
          trigger_id: ctx[:trigger_id]
        )
      end

      # 3) Tell Slack to open the modal
      def tell_slack_to_open_modal(ctx)
        Slack::Client.new(ctx[:org]).views_open(ctx[:modal])
        true
      rescue => e
        Rails.logger.error("views.open failed: #{e}")
        false
      end
    end
  end
end
