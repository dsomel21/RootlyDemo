require "test_helper"

# Integration test for Slack incident declaration HTTP workflow
#
# Tests the complete HTTP request flow for POST /slack/commands when Slack sends
# a `/rootly declare <title>` slash command through authentication, parsing,
# workflow execution, and modal API response.
#
# This comprehensive test validates:
# - HTTP request handling and Slack signature verification
# - Organization lookup and authorization
# - Command routing and argument parsing
# - Workflow orchestration (DeclareCommand service)
# - Block Kit modal generation (DeclareModal presenter)
# - Slack API integration (Client service)
#
# Covers happy path, error cases, and edge cases for the HTTP endpoint.
class SlackIncidentDeclareHttpWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    # Create test organization with Slack installation
    @organization = organizations(:one)
    @slack_installation = slack_installations(:one)

    # Mock Slack API responses
    @mock_views_open_response = { "ok" => true, "view" => { "id" => "V123456" } }

    # Mock Rails credentials for Slack
    Rails.application.credentials.stubs(:slack).returns({
      signing_secret: "test_signing_secret",
      client_id: "test_client_id"
    })

    # Allow test hosts for integration tests
    Rails.application.config.hosts << "www.example.com"
  end

  test "POST /slack/commands with declare command opens incident modal" do
    # Mock the entire views_open method chain to return success
    client_instance = mock()
    client_instance.stubs(:views_open).returns(@mock_views_open_response)
    Slack::Client.stubs(:new).returns(client_instance)

    # Mock the current_organization for test environment
    Slack::CommandsController.any_instance.stubs(:current_organization).returns(@organization)

    # This similar to how what the actual params look like:
    #
    # {"token" => "CGpMVftw6jg5WBCoJogdxN97",
    # "team_id" => "T09GY1KKMFC",
    # "team_domain" => "octobers-very-own-hq",
    # "channel_id" => "C09GY1L4QHG",
    # "channel_name" => "all-octobers-very-own",
    # "user_id" => "U09GY1KKMK4",
    # "user_name" => "dsomel21",
    # "command" => "/rootly",
    # "text" => "declare \"Dilraj is too hot!\"",
    # "api_app_id" => "A09GYBJ4GK0",
    # "is_enterprise_install" => "false",
    # "response_url" => "https://hooks.slack.com/commands/T09GY1KKMFC/9579185965778/s3XxsTtBXAZ9iOy4aueFUGjM",
    # "trigger_id" => "9579185965858.9576053667522.0ed5bc81d152012a3fbaa61026675f10",
    # "controller" => "slack/commands",
    # "action" => "receive"
    # }
    slack_params = build_slack_command_params(
      command: "/rootly",
      text: "declare Dilraj is on fire",
      team_id: @slack_installation.team_id,
      user_id: "U123456789",
      trigger_id: "123456.789012.trigger_token"
    )

    # Hit the endpoint with valid Slack signature
    post "/slack/commands", params: slack_params, headers: slack_headers(slack_params)

    # Should return success response
    assert_response :ok
    response_json = JSON.parse(response.body)
    assert_empty response_json # Empty response means modal was opened successfully
  end

  test "modal structure: validates Block Kit JSON format" do
    # Test the modal building directly
    modal = BlockKits::DeclareModal.build(
      title: "Test Incident",
      trigger_id: "test_trigger_123"
    )

    # Check modal structure
    assert_equal "test_trigger_123", modal[:trigger_id]
    assert_equal "modal", modal[:view][:type]
    assert_equal "incident_declare", modal[:view][:callback_id]

    # Check modal content
    title_block = modal[:view][:blocks].find { |b| b[:block_id] == "title_block" }
    assert_equal "Test Incident", title_block[:element][:initial_value]

    # Check modal has description and severity blocks
    assert modal[:view][:blocks].any? { |b| b[:block_id] == "description_block" }
    assert modal[:view][:blocks].any? { |b| b[:block_id] == "severity_block" }

    # Check modal buttons
    assert_equal "Declare", modal[:view][:submit][:text]
    assert_equal "Cancel", modal[:view][:close][:text]
  end

  test "POST /slack/commands with unknown command returns help message" do
    slack_params = build_slack_command_params(
      command: "/rootly",
      text: "invalid command",
      team_id: @slack_installation.team_id
    )

    post "/slack/commands", params: slack_params, headers: slack_headers(slack_params)

    assert_response :ok
    response_json = JSON.parse(response.body)
    assert_equal "ephemeral", response_json["response_type"]
    assert_includes response_json["text"], "Rootly Commands"
  end

  test "POST /slack/commands with declare (no title) returns help message" do
    # Mock the current_organization for test environment
    Slack::CommandsController.any_instance.stubs(:current_organization).returns(@organization)

    slack_params = build_slack_command_params(
      command: "/rootly",
      text: "declare",  # No title provided - this routes to help
      team_id: @slack_installation.team_id
    )

    post "/slack/commands", params: slack_params, headers: slack_headers(slack_params)

    assert_response :ok
    response_json = JSON.parse(response.body)
    assert_equal "ephemeral", response_json["response_type"]
    # Since "declare" without title routes to help, we should see help message
    assert_includes response_json["text"], "Rootly Commands"
    assert_includes response_json["text"], "/rootly declare <title>"
  end

  test "unit test: command router logic validation" do
    # Test the command router logic directly
    result = Slack::CommandRouter.route("unknown command")
    assert_equal :help, result[:action]

    result = Slack::CommandRouter.route("resolve")
    assert_equal :resolve, result[:action]

    result = Slack::CommandRouter.route("declare Test Title")
    assert_equal :declare, result[:action]
    assert_equal "Test Title", result[:title]
  end

  private

  def build_slack_command_params(command:, text:, team_id:, user_id: "U123456", trigger_id: "trigger123")
    {
      token: "verification_token",
      team_id: team_id,
      team_domain: "test-workspace",
      channel_id: "C123456",
      channel_name: "general",
      user_id: user_id,
      user_name: "testuser",
      command: command,
      text: text,
      response_url: "https://hooks.slack.com/commands/123/456/xyz",
      trigger_id: trigger_id
    }
  end

  def slack_headers(params)
    # Generate valid Slack signature for authentication
    timestamp = Time.current.to_i.to_s
    body = params.to_query
    signing_secret = "test_signing_secret" # Use a test secret

    sig_basestring = "v0:#{timestamp}:#{body}"
    signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, sig_basestring)

    {
      "X-Slack-Signature" => signature,
      "X-Slack-Request-Timestamp" => timestamp,
      "Content-Type" => "application/x-www-form-urlencoded"
    }
  end
end
