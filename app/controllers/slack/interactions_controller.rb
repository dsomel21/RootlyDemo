class Slack::InteractionsController < Slack::BaseController
  # POST /slack/interactions
  #
  # WHAT TRIGGERS THIS:
  # - User clicks a button in Slack
  # - User submits a modal form
  # - User selects from a dropdown
  # - Any interactive element in your Slack app
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

    # Route the interaction to the appropriate handler
    interaction_router = Slack::InteractionRouter.route(payload["type"], payload)

    response = case interaction_router[:action]
    when :create_incident
      puts "🚀 HANDLING CREATE INCIDENT INTERACTION"
      Slack::Workflows::CreateIncidentInteraction.new(
        organization: current_organization,
        payload: payload
      ).call
    when :resolve_incident
      puts "TODO: Implement resolve incident workflow"
      Slack::Response.ok({ response_action: "clear" })
    when :update_user_settings
      puts "TODO: Implement user settings workflow"
      Slack::Response.ok({ response_action: "clear" })
    when :resolve_incident_button
      puts "TODO: Implement resolve button workflow"
      Slack::Response.ok({})
    when :update_incident_status
      puts "TODO: Implement status update workflow"
      Slack::Response.ok({})
    else
      Rails.logger.warn "Unknown interaction action: #{interaction_router[:action]}"
      Slack::Response.ok({})
    end

    render json: response.json, status: response.status
  end
end
