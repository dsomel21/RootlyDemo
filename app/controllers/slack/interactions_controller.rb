class Slack::InteractionsController < Slack::BaseController
  # POST /slack/interactions
  #
  # WHAT TRIGGERS THIS:
  # - User clicks a button in Slack
  # - User submits a modal form
  # - User selects from a dropdown
  # - Any interactive element in your Slack app
  #
  # IMPORTANT: MODAL CANCELLATION BEHAVIOR
  # =====================================
  # When users click "Cancel" or the "X" button on modals:
  # - Slack closes the modal client-side immediately
  # - NO request is sent to this endpoint
  # - This is normal Slack behavior - cancellation needs no server action
  # - Users get immediate visual feedback (modal disappears)
  #
  # We only receive requests when users:
  # - Submit forms (view_submission)
  # - Click interactive elements like buttons/dropdowns (block_actions)
  #
  # RESPONSIBILITY:
  # - Receive form data from modals
  # - Validate the data
  # - Create incidents and Slack channels
  # - Respond to close modal or show errors
  #
  # WHEN IT RUNS:
  # After CommandsController opens a modal and user interacts with it
  #
  # EXAMPLE FLOW:
  # 1. User types: /rootly declare "Database down"
  # 2. CommandsController opens modal
  # 3. User fills modal and clicks "Declare Incident"
  # 4. THIS controller receives the form data
  # 5. We create the incident and Slack channel
  # 6. We close the modal

  def receive
    puts "🚀 SLACK INTERACTION RECEIVED: #{params[:type]}"

    # Parse the payload (Slack sends it as form data)
    payload = JSON.parse(params[:payload])
    interaction_type = payload["type"]

    response = case interaction_type
    when "view_submission"
      handle_view_submission(payload)
    when "block_actions"
      handle_block_actions(payload)
    else
      Rails.logger.warn "Unknown interaction type: #{interaction_type}"
      Slack::Response.ok({})
    end

    render json: response.json, status: response.status
  end

  private

  def handle_view_submission(payload)
    callback_id = payload.dig("view", "callback_id")

    case callback_id
    when "incident_declare"
      puts "🚀 HANDLING CREATE INCIDENT INTERACTION"
      Slack::Workflows::CreateIncidentInteraction.new(
        organization: current_organization,
        payload: payload
      ).call
    when "incident_resolve"
      puts "TODO: Implement resolve incident workflow"
      Slack::Response.ok({ response_action: "clear" })
    when "user_settings"
      puts "TODO: Implement user settings workflow"
      Slack::Response.ok({ response_action: "clear" })
    else
      Rails.logger.warn "Unknown modal callback_id: #{callback_id}"
      Slack::Response.ok({})
    end
  end

  def handle_block_actions(payload)
    action_id = payload.dig("actions", 0, "action_id")

    case action_id
    when "resolve_button"
      puts "TODO: Implement resolve button workflow"
      Slack::Response.ok({})
    when "update_status_select"
      puts "TODO: Implement status update workflow"
      Slack::Response.ok({})
    else
      Rails.logger.warn "Unknown block action: #{action_id}"
      Slack::Response.ok({})
    end
  end
end
