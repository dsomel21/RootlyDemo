class Slack::BaseController < ApplicationController
  require "openssl"

  # Skip CSRF protection for all Slack endpoints
  skip_before_action :verify_authenticity_token

  # Verify all Slack requests and find organization
  before_action :authenticate_slack_request, unless: -> { Rails.env.test? }

  # Make organization available to all Slack controllers
  attr_reader :current_organization

  protected

  def verify_slack_signature
    slack_signature = request.headers["X-Slack-Signature"]
    timestamp = request.headers["X-Slack-Request-Timestamp"]

    return false if slack_signature.blank? || timestamp.blank?

    # Check timestamp (prevent replay attacks)
    return false if (Time.current.to_i - timestamp.to_i).abs > 300 # 5 minutes

    # Build signature
    sig_basestring = "v0:#{timestamp}:#{request.raw_post}"
    signing_secret = Rails.application.credentials.slack[:signing_secret]

    my_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, sig_basestring)

    # Secure comparison
    ActiveSupport::SecurityUtils.secure_compare(my_signature, slack_signature)
  end

  def find_organization_by_team_id(team_id)
    installation = SlackInstallation.find_by(team_id: team_id)

    unless installation
      Rails.logger.error "No installation found for team: #{team_id}"
      return nil
    end

    installation.organization
  end

  def render_unauthorized_slack_response
    render json: {
      response_type: "ephemeral",
      text: "❌ This Slack workspace is not authorized to use Rootly. Please reinstall the app."
    }
  end

  private

  def authenticate_slack_request
    # Verify the request is from Slack
    unless verify_slack_signature
      Rails.logger.error "Invalid Slack signature"
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    # Find the organization based on team_id
    team_id = extract_team_id
    @current_organization = find_organization_by_team_id(team_id)

    unless @current_organization
      return render_unauthorized_slack_response
    end

    Rails.logger.info "Authenticated request from #{@current_organization.name} (#{team_id})"
  end

  def extract_team_id
    # For commands/interactions, team_id comes from different places
    if params[:team_id].present?
      params[:team_id]
    elsif params[:payload].present?
      payload = JSON.parse(params[:payload])
      payload["team"]["id"]
    else
      nil
    end
  end
end
