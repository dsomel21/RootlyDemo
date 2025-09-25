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
    puts "🚀 SLACK COMMAND RECEIVED: #{params[:command]}"

    command_router = Slack::CommandRouter.route(params[:text])

    response = case command_router[:action]
    when :declare
      puts "🚀 HANDLING DECLARE COMMAND"
      Slack::Workflows::DeclareCommand.new.call(organization: current_organization, params: params)
    when :resolve
      puts "🚀 HANDLING RESOLVE COMMAND"
      Slack::Response.err("Resolve command not implemented yet")
    when :help
      puts "🚀 HANDLING HELP COMMAND"
      Slack::Response.ok({
        response_type: "ephemeral",
        text: "🚨 *Rootly Commands:*\n• `/rootly declare <title>` - Create a new incident\n• `/rootly resolve` - Resolve current incident"
      })
    else
      Slack::Response.err("❓ Unknown command: #{params[:text]}")
    end

    render json: response.json, status: response.status
  end
end
