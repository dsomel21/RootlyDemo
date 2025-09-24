class Slack::OauthController < Slack::BaseController
  require "net/http"
  require "uri"
  require "json"

  # Skip authentication for OAuth callback (handles its own auth)
  skip_before_action :authenticate_slack_request

  def callback
    Rails.logger.info "Slack OAuth callback received"

    # Extract OAuth parameters
    code = params[:code]
    state = params[:state]
    error = params[:error]

    # Handle OAuth errors
    if error.present?
      Rails.logger.error "OAuth error: #{error}"
      return render json: { error: "OAuth failed: #{error}" }, status: :bad_request
    end

    # Validate required parameters
    if code.blank?
      Rails.logger.error "Missing authorization code"
      return render json: { error: "No authorization code received" }, status: :bad_request
    end

    # Validate state token (CSRF protection)
    unless validate_state_token(state)
      Rails.logger.error "Invalid state token"
      return render json: { error: "Invalid state token" }, status: :bad_request
    end

    # Complete installation atomically
    begin
      ActiveRecord::Base.transaction do
        token_response = exchange_code_for_tokens(code)
        installation = create_or_update_installation(token_response)

        Rails.logger.info "Slack app installed successfully for #{token_response['team']['name']}"

        render json: {
          status: "success",
          message: "Slack app installed successfully!",
          organization: installation.organization.name,
          team_name: token_response["team"]["name"],
          timestamp: Time.current.iso8601
        }
      end
    rescue => e
      Rails.logger.error "OAuth callback failed: #{e.message}"
      render json: {
        error: "Failed to complete installation: #{e.message}"
      }, status: :internal_server_error
    end
  end

  private

  def validate_state_token(state)
    return false if state.blank?

    decoded = Base64.urlsafe_decode64(state)
    payload = JSON.parse(decoded)

    # Check if token is not too old (5 minutes)
    (Time.current.to_i - payload["timestamp"]) <= 300
  rescue => e
    Rails.logger.error "Invalid state token: #{e.message}"
    false
  end

  def exchange_code_for_tokens(code)
    uri = URI("https://slack.com/api/oauth.v2.access")

    params = {
      client_id: Rails.application.credentials.slack[:client_id],
      client_secret: Rails.application.credentials.slack[:client_secret],
      code: code,
      redirect_uri: slack_oauth_callback_url
    }

    response = Net::HTTP.post_form(uri, params)
    token_data = JSON.parse(response.body)

    unless token_data["ok"]
      raise "Slack API error: #{token_data['error']}"
    end

    token_data
  end

  def create_or_update_installation(token_response)
    team_id = token_response["team"]["id"]
    team_name = token_response["team"]["name"]
    bot_token = token_response["access_token"]

    # Create or find organization based on Slack team
    organization = find_or_create_organization_for_team(team_id, team_name)

    # Create or update the Slack installation
    installation = SlackInstallation.find_or_initialize_by(
      organization: organization,
      team_id: team_id
    )

    installation.update!(
      bot_user_id: token_response["bot_user_id"],
      bot_access_token_ciphertext: bot_token,
      signing_secret_ciphertext: Rails.application.credentials.slack[:signing_secret]
    )

    installation
  end

  def find_or_create_organization_for_team(team_id, team_name)
    # Check if we already have an installation for this team
    existing_installation = SlackInstallation.find_by(team_id: team_id)
    return existing_installation.organization if existing_installation

    # Create a new organization for this Slack team
    Organization.create!(name: team_name)
  end
end
