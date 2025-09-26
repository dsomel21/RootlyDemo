module Slack
  # Routes different types of Slack interactions to appropriate handlers
  #
  # IMPORTANT: SLACK MODAL BEHAVIOR NOTES
  # ====================================
  #
  # Slack only sends `view_closed` events in specific cases:
  # - When the modal is closed programmatically via API
  # - Due to certain system events or timeouts
  # - NOT when users click the "Cancel" button or close button (X)
  #
  # When users click "Cancel" or "X":
  # - Slack simply closes the modal client-side
  # - No event is sent to your endpoint
  # - This is by design - Slack assumes "Cancel" means "do nothing"
  # - No server interaction is needed for user-initiated cancellations
  #
  # Therefore, we only handle:
  # - view_submission: When users submit forms (click primary action button)
  # - block_actions: When users interact with buttons, dropdowns, etc.
  #
  # We do NOT handle view_closed events because they're unreliable for user actions.
  class InteractionRouter
    def self.route(interaction_type, payload)
      case interaction_type
      when "view_submission"
        route_view_submission(payload)
      when "block_actions"
        route_block_actions(payload)
      else
        { action: :unknown, type: interaction_type }
      end
    end

    private

    # 📌 TODO: Add docs here about how Slack has these 2 action buttons
    def self.route_view_submission(payload)
      callback_id = payload.dig("view", "callback_id")

      case callback_id
      when "incident_declare"
        { action: :create_incident, callback_id: callback_id, payload: payload }
      when "incident_resolve"
        { action: :resolve_incident, callback_id: callback_id, payload: payload }
      when "user_settings"
        { action: :update_user_settings, callback_id: callback_id, payload: payload }
      else
        { action: :unknown_modal, callback_id: callback_id, payload: payload }
      end
    end


    def self.route_block_actions(payload)
      # Future: Route different button/dropdown actions
      action_id = payload.dig("actions", 0, "action_id")

      case action_id
      when "resolve_button"
        { action: :resolve_incident_button, action_id: action_id, payload: payload }
      when "update_status_select"
        { action: :update_incident_status, action_id: action_id, payload: payload }
      else
        { action: :unknown_action, action_id: action_id, payload: payload }
      end
    end
  end
end
