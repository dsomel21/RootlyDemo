class WebhookController < ApplicationController
  # Skip CSRF protection for webhook endpoints
  skip_before_action :verify_authenticity_token, only: [ :receive ]

  def receive
    # Log all the juicy request details
    Rails.logger.info "🚀 INCOMING POST REQUEST"
    Rails.logger.info "=" * 50
    Rails.logger.info "📍 URL: #{request.url}"
    Rails.logger.info "🔗 Path: #{request.path}"
    Rails.logger.info "📝 Method: #{request.method}"
    Rails.logger.info "🌐 Remote IP: #{request.remote_ip}"
    Rails.logger.info "🕐 Timestamp: #{Time.current}"

    # Headers
    Rails.logger.info "📋 HEADERS:"
    request.headers.each do |key, value|
      # Skip boring Rails internal headers
      next if key.start_with?("action_dispatch", "rack.", "puma.")
      Rails.logger.info "  #{key}: #{value}"
    end

    # Request body
    Rails.logger.info "📦 RAW BODY:"
    body = request.raw_post
    Rails.logger.info "  Length: #{body.bytesize} bytes"
    Rails.logger.info "  Content: #{body.present? ? body : '(empty)'}"

    # Parsed params (if any)
    Rails.logger.info "🔧 PARSED PARAMS:"
    params.except(:controller, :action).each do |key, value|
      Rails.logger.info "  #{key}: #{value.inspect}"
    end

    # Query string
    if request.query_string.present?
      Rails.logger.info "❓ QUERY STRING: #{request.query_string}"
    end

    Rails.logger.info "=" * 50
    Rails.logger.info "✅ REQUEST LOGGED SUCCESSFULLY"

    # Return a simple JSON response
    render json: {
      status: "received",
      timestamp: Time.current.iso8601,
      message: "Request logged successfully - check your Rails logs!"
    }, status: :ok
  end
end
