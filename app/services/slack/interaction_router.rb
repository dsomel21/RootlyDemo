module Slack
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
