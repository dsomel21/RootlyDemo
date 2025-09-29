class Slack::CommandsController < Slack::BaseController
  # POST /slack/commands
  #
  # Handles the `/rootly` slash command from Slack.
  #
  # NOTE:
  # Slack only lets us define one slash command here: `/rootly`.
  # Therefore, `params[:command]` will always be "/rootly".
  # We parse subcommands (e.g. "declare <title>", "resolve") from `params[:text]`.
  #
  # FLOW:
  # Slack user types `/rootly declare "Something"` → we parse `declare "Something"` from params[:text]

  def receive
    # Parse command text to determine action
    text = params[:text].to_s.strip

    response = case text
    when /^declare\s+(.+)/i
      # Extract title from declare command
      title = $1.strip
      Slack::Workflows::DeclareCommand.new.call(organization: current_organization, params: params)
    when /^resolve$/i
      Slack::Workflows::ResolveIncidentCommand.new(
        organization: current_organization,
        params: params
      ).call
    else
      # Show help for unknown commands or empty commands
      Slack::Response.ok({
        response_type: "ephemeral",
        text: "🚨 *Rootly Commands:*\n• `/rootly declare <title>` - Create a new incident\n• `/rootly resolve` - Resolve current incident (only works in incident channels)"
      })
    end

    render json: response.json, status: response.status
  end
end
