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
          <!-- Color Palette -->
          <style>
            :root {
              --bg-0: #0D0B1A;
              --bg-1: #151327;
              --bg-2: #1B1832;
              --br-primary: #7B2CBF;
              --br-muted: rgba(255,255,255,0.12);
              --br-glow: rgba(123,44,191,0.35);
              --text-strong: #FFFFFF;
              --text: #E7E3F4;
              --text-muted: #C7C2DD;
              --text-dim: #9A96B5;
              --accent: #7B2CBF;
              --accent-2: #A461FF;
              --sev0: #FF5468;
              --sev1: #FFB02E;
              --sev2: #FFD166;
              --success: #25D0A6;
            }
          </style>
      #{'    '}
          <!-- Gradients -->
          <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#0D0B1A;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#151327;stop-opacity:1" />
          </linearGradient>
      #{'    '}
          <linearGradient id="accentGradient" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" style="stop-color:#7B2CBF;stop-opacity:0.35" />
            <stop offset="100%" style="stop-color:#A461FF;stop-opacity:0.35" />
          </linearGradient>
      #{'    '}
          <linearGradient id="statusGradient" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" style="stop-color:#FFD166;stop-opacity:0.4" />
            <stop offset="100%" style="stop-color:#FFB02E;stop-opacity:0.4" />
          </linearGradient>
      #{'    '}
          <!-- Filters -->
          <filter id="glow">
            <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
            <feMerge>
              <feMergeNode in="coloredBlur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
      #{'    '}
          <filter id="softGlow">
            <feGaussianBlur stdDeviation="8" result="coloredBlur"/>
            <feMerge>
              <feMergeNode in="coloredBlur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>

        <!-- Background -->
        <rect width="1280" height="720" fill="url(#bgGradient)" rx="28"/>
        #{generate_micro_noise}

        <!-- Header Card -->
        <rect x="60" y="60" width="1160" height="120" fill="#151327" stroke="url(#accentGradient)" stroke-width="2" rx="28"/>
        <text x="100" y="90" fill="#FFFFFF" font-family="Inter, Montserrat, sans-serif" font-size="48" font-weight="700" dominant-baseline="hanging">
          Incident ##{@incident.number}
        </text>
        <text x="100" y="140" fill="#7B2CBF" font-family="Inter, Montserrat, sans-serif" font-size="24" font-weight="600" dominant-baseline="hanging">
          #{@incident.status&.upcase || 'RESOLVED'}
        </text>

        <!-- Middle Card -->
        <rect x="60" y="204" width="1160" height="200" fill="#151327" stroke="rgba(255,255,255,0.10)" stroke-width="1" rx="28"/>
        <text x="104" y="248" fill="#7B2CBF" font-family="Inter, Montserrat, sans-serif" font-size="36" font-weight="700" dominant-baseline="hanging" filter="url(#softGlow)" style="font-feature-settings: 'tnum' 1; -webkit-font-feature-settings: 'tnum' 1;">
          #{format_duration(@incident.resolved_duration_seconds)}
        </text>
        <text x="104" y="280" fill="#9A96B5" font-family="Inter, Montserrat, sans-serif" font-size="18" font-weight="500" dominant-baseline="hanging">
          #{categorize_resolution_speed_for_display(@incident.resolved_duration_seconds)}
        </text>
        <text x="104" y="320" fill="#FFFFFF" font-family="Inter, Montserrat, sans-serif" font-size="24" font-weight="600" dominant-baseline="hanging">
          #{@incident.title.truncate(60)}
        </text>
        <text x="104" y="350" fill="#C7C2DD" font-family="Inter, Montserrat, sans-serif" font-size="16" font-weight="400" dominant-baseline="hanging">
          #{analytics[:total_messages]} messages • #{analytics[:participants].size} participants
        </text>

        <!-- Participants Card -->
        <rect x="60" y="428" width="1160" height="232" fill="#151327" stroke="rgba(255,255,255,0.10)" stroke-width="1" rx="28"/>
        #{generate_participant_circles(top_participants, message_counts)}

        <!-- Quote Pill -->
        #{format_quote_line(analytics[:quote]) if analytics[:quote]}

        <!-- Rootly Logo -->
        <image href="https://res.cloudinary.com/dip5mdxwe/image/upload/v1759080454/RootlyLogo.min_putzc4.svg"#{' '}
               x="1148" y="584" width="120" height="60" opacity="0.7" fill="#FFFFFF"/>

      </svg>
    SVG
  end

  def generate_micro_noise
    # Add micro-noise layer for polish (3-4% opacity)
    (0..50).map do |i|
      x = rand(1280)
      y = rand(720)
      opacity = rand(0.03..0.04)
      size = rand(0.5..2)
      "<circle cx='#{x}' cy='#{y}' r='#{size}' fill='#ffffff' opacity='#{opacity}'/>"
    end.join
  end

  def generate_participant_circles(slack_users, message_counts)
    return "" if slack_users.blank?

    # Center avatars with 120px left gutter
    card_width = 1160
    left_gutter = 120
    available_width = card_width - left_gutter - 40  # 40px right padding
    avatar_spacing = available_width / slack_users.length
    start_x = 60 + left_gutter + (avatar_spacing / 2)

    slack_users.each_with_index.map do |user, index|
      x = start_x + (index * avatar_spacing)
      y = 542  # Moved up 6px from 548

      name = sanitize_text(user.display_name || user.real_name || user.slack_user_id, 12)
      message_count = message_counts[user.slack_user_id] || 0
      message_label = message_count == 1 ? "1 message" : "#{message_count} messages"
      safe_message_label = sanitize_text(message_label, 20)

      <<~CIRCLE
        <defs>
          <clipPath id="circle#{index}">
            <circle cx="#{x}" cy="#{y}" r="50"/>
          </clipPath>
        </defs>
        <circle cx="#{x}" cy="#{y}" r="55" fill="#7B2CBF" opacity="0.25" stroke="#7B2CBF" stroke-width="2"/>
        #{generate_avatar_content(user, x, y, index)}
        <text x="#{x}" y="#{y+70}" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Montserrat, sans-serif" font-size="14" font-weight="600" dominant-baseline="hanging">
          #{name}
        </text>
        <text x="#{x}" y="#{y+96}" text-anchor="middle" fill="#C7C2DD" font-family="Inter, Montserrat, sans-serif" font-size="12" font-weight="400" dominant-baseline="hanging">
          #{safe_message_label}
        </text>
      CIRCLE
    end.join
  end

  def format_quote_line(quote)
    safe_text = sanitize_text(quote[:text], 100)
    safe_author = sanitize_text(quote[:author], 40)
    return "" if safe_text.blank?

    # Quote pill positioned after avatar gutter, shrunk and shifted right
    card_width = 1160
    left_gutter = 120
    available_width = card_width - left_gutter - 40
    pill_width = 752  # Reduced by 48px (24px each side)
    pill_x = 60 + left_gutter + (available_width - pill_width) / 2 + 8  # Shifted right 8px

    <<~QUOTE.strip
      <rect x="#{pill_x}" y="598" width="#{pill_width}" height="60" fill="#1B1832" stroke="#7B2CBF" stroke-width="1" rx="15" opacity="0.3"/>
      <text x="#{pill_x + 20}" y="618" fill="#7B2CBF" font-family="Inter, Montserrat, sans-serif" font-size="20" font-weight="600" opacity="0.6" dominant-baseline="hanging">"</text>
      <text x="#{pill_x + pill_width/2}" y="628" text-anchor="middle" fill="#E7E3F4" font-family="Inter, Montserrat, sans-serif" font-size="16" font-style="italic" font-weight="500" dominant-baseline="hanging">
        #{safe_text}
      </text>
      <text x="#{pill_x + pill_width/2}" y="648" text-anchor="middle" fill="#C7C2DD" font-family="Inter, Montserrat, sans-serif" font-size="14" font-weight="400" dominant-baseline="hanging">
        — #{safe_author}
      </text>
    QUOTE
  end

  def generate_avatar_content(user, x, y, index)
    # Try to get real avatar as data URI, fallback to initials
    avatar_data_uri = fetch_avatar_as_data_uri(user.avatar_url)
    initials = generate_initials(user.display_name || user.real_name || user.slack_user_id)

    if avatar_data_uri
      # Use real avatar
      "<image href=\"#{avatar_data_uri}\" x=\"#{x-50}\" y=\"#{y-50}\" width=\"100\" height=\"100\" clip-path=\"url(#circle#{index})\"/>"
    else
      # Use initials with gradient background
      <<~AVATAR
        <defs>
          <linearGradient id="avatarGrad#{index}" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#7B2CBF;stop-opacity:0.8" />
            <stop offset="100%" style="stop-color:#A461FF;stop-opacity:0.8" />
          </linearGradient>
        </defs>
        <circle cx="#{x}" cy="#{y}" r="50" fill="url(#avatarGrad#{index})"/>
        <text x="#{x}" y="#{y+6}" text-anchor="middle" fill="#FFFFFF" font-family="Inter, Montserrat, sans-serif" font-size="20" font-weight="700" dominant-baseline="middle">
          #{initials}
        </text>
      AVATAR
    end
  end

  def fetch_avatar_as_data_uri(avatar_url)
    return nil unless avatar_url.present? && avatar_url.start_with?("http")

    begin
      require "net/http"
      require "base64"

      uri = URI(avatar_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      http.open_timeout = 10

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      # Follow redirects
      redirect_count = 0
      while response.code.start_with?("3") && redirect_count < 5
        redirect_count += 1
        location = response["location"]
        break unless location

        redirect_uri = URI(location)
        redirect_uri = URI.join(uri, location) if location.start_with?("/")

        http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
        http.use_ssl = true
        http.read_timeout = 10
        http.open_timeout = 10

        request = Net::HTTP::Get.new(redirect_uri)
        response = http.request(request)
      end

      if response.code == "200"
        content_type = response["content-type"] || "image/jpeg"
        base64_data = Base64.strict_encode64(response.body)
        puts "✅ Successfully fetched avatar (#{response.body.length} bytes)"
        "data:#{content_type};base64,#{base64_data}"
      else
        puts "⚠️  Failed to fetch avatar: HTTP #{response.code}"
        nil
      end
    rescue => e
      puts "⚠️  Error fetching avatar: #{e.message}"
      nil
    end
  end

  def generate_initials(name)
    return "?" if name.blank?

    words = name.split
    if words.length >= 2
      "#{words.first[0]}#{words.last[0]}".upcase
    else
      name[0..1].upcase
    end
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

    # Send with modern, sleek message format
    message = {
      channel: @incident.slack_channel.slack_channel_id,
      text: "🎯 *Incident ##{@incident.number} Analytics* 🎯\n\nResolution complete with detailed insights.\n\n#{image_url}\n\n*Key Metrics:*\n• #{analytics[:participants].size} team members participated\n• #{analytics[:total_messages]} messages exchanged\n• Resolved in #{analytics[:duration]} (#{analytics[:resolution_speed]})"
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
      "LIGHTNING FAST"
    when 16..60
      "BLAZING FAST"
    when 61..240
      "SOLID SPEED"
    when 241..720
      "Could Be Faster"
    else
      "Time to Optimize"
    end
  end

  def categorize_resolution_speed_for_display(duration_seconds)
    case duration_seconds
    when 0..300
      "Lightning Fast"
    when 301..1800
      "Quick Resolution"
    when 1801..3600
      "Good Response Time"
    when 3601..7200
      "Standard Resolution"
    else
      "Extended Resolution"
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
