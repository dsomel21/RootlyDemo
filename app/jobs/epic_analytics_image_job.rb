# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "digest"
require "cgi"

class EpicAnalyticsImageJob < ApplicationJob
  queue_as :default

  # Generates an EPIC analytics visualization with circular profile images!
  def perform(incident_id)
    @incident = Incident.find(incident_id)
    @organization = @incident.organization

    puts "🔥 Generating EPIC analytics visualization for incident ##{@incident.number}..."

    # Get analytics data
    analytics = gather_analytics_data
    return unless analytics[:participants].any?

    # Create the epic image
    image_url = create_epic_analytics_image(analytics)

    if image_url
      puts "🔥 EPIC analytics visualization generated!"
      puts "🔗 Image URL: #{image_url}"

      # Send to incident channel with proper Slack blocks
      send_epic_image_to_slack(image_url, analytics)
      puts "✅ EPIC analytics visualization sent to Slack!"
    else
      puts "❌ Failed to generate analytics visualization"
    end
  end

  private

  def gather_analytics_data
    return {} unless @incident.slack_channel

    analytics = @incident.gather_slack_analytics || {}
    messages = analytics[:messages] || {}
    duration_seconds = @incident.resolved_duration_seconds

    analytics[:total_messages] = messages[:total] || 0
    analytics[:duration] = format_duration(duration_seconds)
    analytics[:resolution_speed] = categorize_resolution_speed_for_display(duration_seconds)

    analytics
  end

  def create_epic_analytics_image(analytics)
    puts "🎨 Creating EPIC analytics visualization with circular profile images..."

    # Create an SVG with HERO text and circular profile images
    svg_content = create_epic_svg_content(analytics)

    # Upload to Cloudinary and convert to PNG for better Slack display
    upload_result = upload_svg_to_cloudinary(svg_content, "incident_#{@incident.id}_epic_#{Time.now.to_i}")
    if upload_result
      # Convert to PNG for better Slack compatibility
      png_url = convert_to_png(upload_result["public_id"])
      png_url || upload_result["secure_url"]
    else
      nil
    end
  end

  def create_epic_svg_content(analytics)
    participants = analytics[:participants] || []
    message_counts = analytics.dig(:messages, :by_id) || {}
    top_participants = participants.sort_by { |user| -(message_counts[user.slack_user_id] || 0) }.first(6)

    <<~SVG
      <svg width="1280" height="720" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#0f0f23;stop-opacity:1" />
            <stop offset="50%" style="stop-color:#1a1a2e;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#16213e;stop-opacity:1" />
          </linearGradient>
          <filter id="glow">
            <feGaussianBlur stdDeviation="4" result="coloredBlur"/>
            <feMerge>
              <feMergeNode in="coloredBlur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>

        <rect width="1280" height="720" fill="url(#grad1)"/>
        #{generate_subtle_grid}

        <text x="80" y="150" fill="#00ff88" font-family="Impact, Arial Black, sans-serif" font-size="80" font-weight="900" filter="url(#glow)">
          ##{@incident.number} INCIDENT RESOLVED! 🚨
        </text>

        <text x="80" y="220" fill="#ffffff" font-family="Arial Black, sans-serif" font-size="36" font-weight="900">
          #{@incident.title.truncate(80).upcase}
        </text>

        <text x="80" y="320" fill="#ffd700" font-family="Arial Black, sans-serif" font-size="64" font-weight="bold">
          ⏱️ #{format_duration(@incident.resolved_duration_seconds)}
        </text>
        <text x="1200" y="320" text-anchor="end" fill="#ffaa00" font-family="Arial Black, sans-serif" font-size="64" font-weight="bold" opacity="0.5">
          #{categorize_resolution_speed_for_display(@incident.resolved_duration_seconds)}
        </text>

        #{format_quote_line(analytics[:quote]) if analytics[:quote]}

        #{generate_participant_circles(top_participants, message_counts)}
      </svg>
    SVG
  end

  def generate_subtle_grid
    (0..12).map { |i| "<line x1='#{i * 100}' y1='0' x2='#{i * 100}' y2='720' stroke='#ffffff' stroke-width='0.5' opacity='0.05'/>" }.join +
      (0..7).map { |i| "<line x1='0' y1='#{i * 100}' x2='1280' y2='#{i * 100}' stroke='#ffffff' stroke-width='0.5' opacity='0.05'/>" }.join
  end

  def generate_participant_circles(slack_users, message_counts)
    return "" if slack_users.blank?

    slack_users.each_with_index.map do |user, index|
      spacing = 180
      start_x = 90
      x = start_x + (index * spacing)
      y = 550

      name = sanitize_text(user.display_name || user.real_name || user.slack_user_id, 12)
      message_count = message_counts[user.slack_user_id] || 0
      message_label = message_count == 1 ? "1 message" : "#{message_count} messages"
      safe_message_label = sanitize_text(message_label, 20)

      <<~CIRCLE
        <defs>
          <clipPath id="circle#{index}">
            <circle cx="#{x}" cy="#{y}" r="75"/>
          </clipPath>
        </defs>
        <circle cx="#{x}" cy="#{y}" r="79" fill="#00ff88" opacity="0.9" stroke="#ffffff" stroke-width="4"/>
        <image href="#{user.avatar_url}" x="#{x-75}" y="#{y-75}" width="150" height="150" clip-path="url(#circle#{index})"/>
        <text x="#{x}" y="#{y+100}" text-anchor="middle" fill="#ffffff" font-family="Arial Black, sans-serif" font-size="18" font-weight="bold">
          #{name}
        </text>
        <text x="#{x}" y="#{y+130}" text-anchor="middle" fill="#00ff88" font-family="Arial Black, sans-serif" font-size="16" font-weight="bold">
          #{safe_message_label}
        </text>
      CIRCLE
    end.join
  end

  def format_quote_line(quote)
    safe_text = sanitize_text(quote[:text], 100)
    safe_author = sanitize_text(quote[:author], 40)
    return "" if safe_text.blank?

    <<~QUOTE.strip
      <text x="160" y="360" fill="#ffaa00" font-family="Arial Black, sans-serif" font-size="120" font-weight="900" opacity="0.4">“</text>
      <text x="640" y="420" text-anchor="middle" fill="#ffffff" font-family="Arial Black, sans-serif" font-size="24" font-style="italic" font-weight="900">
        #{safe_text}
      </text>
      <text x="640" y="460" text-anchor="middle" fill="#00ff88" font-family="Arial Black, sans-serif" font-size="22" font-weight="bold">
        — #{safe_author}
      </text>
    QUOTE
  end

  def upload_svg_to_cloudinary(svg_content, public_id)
    upload_url = "https://api.cloudinary.com/v1_1/#{cloudinary_config[:cloud_name]}/image/upload"

    timestamp = Time.now.to_i.to_s

    # Create base64 encoded SVG
    require "base64"
    svg_base64 = Base64.strict_encode64(svg_content)

    params = {
      "file" => "data:image/svg+xml;base64,#{svg_base64}",
      "public_id" => public_id,
      "timestamp" => timestamp,
      "api_key" => cloudinary_config[:api_key]
    }

    # Create signature
    params_to_sign = params.reject { |k, v| k == "api_key" || k == "file" }
    signature_string = params_to_sign.sort.map { |k, v| "#{k}=#{v}" }.join("&") + cloudinary_config[:api_secret]
    signature = Digest::SHA1.hexdigest(signature_string)
    params["signature"] = signature

    # Make request
    uri = URI(upload_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(params)

    response = http.request(request)
    result = JSON.parse(response.body)

    if response.code == "200"
      puts "✅ EPIC analytics image uploaded: #{result['public_id']}"
      result
    else
      puts "❌ Upload failed: #{result.dig('error', 'message')}"
      puts "   Full error: #{result.inspect}"
      nil
    end
  end

  def send_epic_image_to_slack(image_url, analytics)
    return unless @incident.slack_channel

    client = Slack::Client.new(@organization)

    # Send with simple message format that works reliably
    message = {
      channel: @incident.slack_channel.slack_channel_id,
      text: "🔥 *EPIC Incident ##{@incident.number} Analytics!* 🔥\n\nIncident resolved with style!\n\n#{image_url}\n\n*Quick Victory Stats:*\n• #{analytics[:participants].size} heroes participated\n• #{analytics[:total_messages]} battle messages\n• Resolved in #{analytics[:duration]} (#{analytics[:resolution_speed]})"
    }

    client.chat_post_message(message)
  end

  # Helper methods
  def calculate_duration
    return "Unknown" unless @incident.resolved_at && @incident.declared_at

    duration_seconds = (@incident.resolved_at - @incident.declared_at).to_i
    format_duration(duration_seconds)
  end

  def format_duration(seconds)
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{seconds / 60}m #{seconds % 60}s"
    else
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      "#{hours}h #{minutes}m"
    end
  end

  def categorize_resolution_speed
    return "Unknown" unless @incident.resolved_at && @incident.declared_at

    duration_minutes = ((@incident.resolved_at - @incident.declared_at) / 60).to_i

    case duration_minutes
    when 0..15
      "⚡ LIGHTNING FAST"
    when 16..60
      "🚀 BLAZING FAST"
    when 61..240
      "✅ SOLID SPEED"
    when 241..720
      "🐌 Could Be Faster"
    else
      "🦥 Time to Optimize"
    end
  end

  def categorize_resolution_speed_for_display(duration_seconds)
    case duration_seconds
    when 0..300
      "⚡ Lightning Fast"
    when 301..1800
      "🚀 Quick Resolution"
    when 1801..3600
      "👍 Good Response Time"
    when 3601..7200
      "⏰ Standard Resolution"
    else
      "🐌 Extended Resolution"
    end
  end

  def extract_links_from_message(message)
    text = message["text"] || ""
    text.scan(/https?:\/\/[^\s]+/).flatten
  end

  def extract_files_from_message(message)
    message["files"] || []
  end

  def convert_to_png(public_id)
    # Generate PNG URL using Cloudinary transformation (720p for efficiency)
    png_url = "https://res.cloudinary.com/#{cloudinary_config[:cloud_name]}/image/upload/f_png,q_auto,w_1280,h_720/#{public_id}"

    puts "🖼️  720p PNG URL: #{png_url}"
    png_url
  end

  def cloudinary_config
    @cloudinary_config ||= Rails.application.credentials.cloudinary
  end

  def sanitize_text(text, max_length)
    stripped = text.to_s.gsub(/[\r\n]/, " ").strip
    truncated = stripped.length > max_length ? stripped[0...max_length] + "…" : stripped
    CGI.escapeHTML(truncated)
  end
end
