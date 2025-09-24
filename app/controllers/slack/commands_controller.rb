class Slack::CommandsController < Slack::BaseController
  # POST /slack/commands
  #
  # WHAT TRIGGERS THIS:
  # - User types a slash command in Slack: /rootly declare "Something"
  # - User types: /rootly resolve
  # - User types: /rootly (with no arguments)
  #
  # RESPONSIBILITY:
  # - Parse the command text
  # - Figure out what the user wants to do
  # - Open modals for complex actions
  # - Show help text for invalid commands
  #
  # WHEN IT RUNS:
  # Immediately when user presses Enter after typing /rootly command
  #
  # EXAMPLE FLOW:
  # 1. User types: /rootly declare "Database is down"
  # 2. THIS controller receives the command
  # 3. We parse "declare" and extract "Database is down"
  # 4. We open a modal with the title pre-filled
  # 5. InteractionsController handles what happens next

  def receive
    puts "🚀 SLACK COMMAND RECEIVED: #{params[:command]}"

    case params[:command]
    when "/rootly"
      puts "🚀 HANDLING ROOTLY COMMAND"
    else
      render json: {
        response_type: "ephemeral",
        text: "❓ Unknown command: #{params[:command]}"
      }
    end
  end
end
