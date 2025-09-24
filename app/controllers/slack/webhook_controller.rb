class Slack::WebhookController < ApplicationController
  # Skip CSRF protection for webhook endpoints
  skip_before_action :verify_authenticity_token, only: [ :receive ]

  def receive
    Rails.logger.info "Webhook received from #{request.remote_ip}"

    # Log essential request details for debugging
    log_request_details

    # Return simple acknowledgment
    render json: {
      status: "received",
      timestamp: Time.current.iso8601,
      message: "Webhook received successfully"
    }
  end

  private

  def log_request_details
    Rails.logger.info "Request details:"
    Rails.logger.info "  URL: #{request.url}"
    Rails.logger.info "  Method: #{request.method}"
    Rails.logger.info "  Content-Type: #{request.content_type}"
    Rails.logger.info "  Body length: #{request.raw_post.bytesize} bytes"

    # Log important headers
    %w[X-Slack-Signature X-Slack-Request-Timestamp User-Agent].each do |header|
      value = request.headers[header]
      Rails.logger.info "  #{header}: #{value}" if value.present?
    end

    # Log team_id if present (for organization lookup)
    Rails.logger.info "  Team ID: #{params[:team_id]}" if params[:team_id].present?
  end
end
