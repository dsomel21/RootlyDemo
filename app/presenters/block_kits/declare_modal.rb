module BlockKits
  # Builds the incident declaration modal using Slack's Block Kit format
  #
  # MODAL BEHAVIOR NOTES:
  # ====================
  # - submit: "Declare" button triggers view_submission event to our server
  # - close: "Cancel" button closes modal client-side (no server request)
  # - Users can also close with "X" button or ESC key (no server request)
  #
  # This is standard Slack behavior - only form submissions need server interaction.
  class DeclareModal
    def self.build(title:, trigger_id:)
      {
        trigger_id: trigger_id,
        view: {
          type: "modal",
          callback_id: "incident_declare",
          title:  { type: "plain_text", text: "🚨 Declare Incident" },
          submit: { type: "plain_text", text: "Declare" },
          close:  { type: "plain_text", text: "Cancel" },
          blocks: [
            {
              type: "input",
              block_id: "title_block",
              element: {
                type: "plain_text_input",
                action_id: "title_input",
                initial_value: title
              },
              label: { type: "plain_text", text: "Incident Title" }
            },
            {
              type: "input",
              block_id: "description_block",
              optional: true,
              element: {
                type: "plain_text_input",
                action_id: "description_input",
                multiline: true
              },
              label: { type: "plain_text", text: "Description (optional)" }
            },
            {
              type: "input",
              block_id: "severity_block",
              optional: true,
              element: {
                type: "static_select",
                action_id: "severity_select",
                initial_option: { text: { type: "plain_text", text: "SEV2 - Medium" }, value: "sev2" },
                options: [
                  { text: { type: "plain_text", text: "SEV0 - Critical" }, value: "sev0" },
                  { text: { type: "plain_text", text: "SEV1 - High" },     value: "sev1" },
                  { text: { type: "plain_text", text: "SEV2 - Medium" },   value: "sev2" }
                ]
              },
              label: { type: "plain_text", text: "Severity (optional)" }
            }
          ]
        }
      }
    end
  end
end
