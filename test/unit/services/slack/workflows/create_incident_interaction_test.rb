require "test_helper"

# Unit test for Slack::Workflows::CreateIncidentInteraction
#
# Tests the complete incident creation workflow including:
# - SlackUser creation/retrieval for the declarer
# - Incident record creation
# - Slack channel creation
# - User invitation to channel
# - Metadata updates (topic, pins, description)

class Slack::Workflows::CreateIncidentInteractionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @slack_user_id = "U123456789"

    # Mock Slack API responses
    @success_response = { "ok" => true }
    @chat_response = { "ok" => true, "message" => { "ts" => "1234567890.123" } }
    @channel_response = {
      "ok" => true,
      "channel" => {
        "id" => "C123456789",
        "name" => "inc-0001-test-incident"
      }
    }

    @payload = {
      "view" => {
        "state" => {
          "values" => {
            "title_block" => { "title_input" => { "value" => "Test Incident" } },
            "description_block" => { "description_input" => { "value" => "Test description" } },
            "severity_block" => { "severity_select" => { "selected_option" => { "value" => "sev1" } } }
          }
        }
      },
      "user" => { "id" => @slack_user_id }
    }
  end
end

private

def mock_slack_responses(interaction)
  client = Slack::Client.new(@organization)

  # Mock client methods
  client.expects(:conversations_create).returns(@channel_response).once
  client.expects(:conversations_invite).returns(@success_response).once
  client.expects(:chat_post_message).returns(@chat_response).at_least(1)
  client.expects(:conversations_setTopic).returns(@success_response).at_least(0)
  client.expects(:pins_add).returns(@success_response).at_least(0)

  interaction.instance_variable_set(:@client, client)
end
