# Sidekiq Job: Gathers comprehensive incident analytics when incident is resolved.
# Analyzes channel history, participants, messages, links, and files shared.
# Outputs detailed statistics to console for now.

class GatherIncidentAnalyticsJob < ApplicationJob
  queue_as :default

  # Sidekiq-specific retry configuration
  sidekiq_options retry: 2, backtrace: true

  def perform(incident_id)
    Rails.logger.info "📊 Gathering incident analytics for incident #{incident_id}"

    incident = Incident.find(incident_id)

    unless incident.slack_channel
      Rails.logger.warn "❌ No Slack channel found for incident #{incident_id}"
      return
    end

    unless incident.resolved?
      Rails.logger.warn "❌ Incident #{incident_id} is not resolved yet"
      return
    end

    begin
      client = Slack::Client.new(incident.organization)
      channel_id = incident.slack_channel.slack_channel_id

      # Gather all the analytics data
      analytics = {
        incident: gather_incident_info(incident),
        participants: gather_participants(client, channel_id, incident.organization),
        messages: gather_message_stats(client, channel_id, incident.organization),
        links_and_files: gather_shared_content(client, channel_id),
        timeline: gather_timeline_info(incident)
      }

      # Print comprehensive analytics to console
      print_incident_analytics(analytics)

      Rails.logger.info "✅ Incident analytics gathered successfully for incident ##{incident.number}"

    rescue => e
      Rails.logger.error "❌ Failed to gather incident analytics: #{e.message}"
      Rails.logger.error "   Incident: #{incident_id} (#{incident.title})"
      Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join(', ')}"

      # Re-raise to trigger Sidekiq retry logic
      raise e
    end
  end

  private

  # Gather basic incident information
  def gather_incident_info(incident)
    duration = incident.resolved_at - incident.declared_at
    {
      number: incident.number,
      title: incident.title,
      severity: incident.severity,
      declared_at: incident.declared_at,
      resolved_at: incident.resolved_at,
      duration_seconds: duration.to_i,
      duration_human: format_duration(duration),
      channel_name: incident.slack_channel.name
    }
  end

  # Gather information about all participants in the channel
  def gather_participants(client, channel_id, organization)
    Rails.logger.info "🔍 Gathering participant information..."

    # Get channel history to find all users who participated
    messages = fetch_all_messages(client, channel_id)
    participant_ids = messages.map { |msg| msg["user"] }.compact.uniq

    participants = []
    participant_ids.each do |user_id|
      next if user_id.start_with?("B") # Skip bot messages

      # Find or fetch user profile
      slack_user = organization.slack_users.find_by(slack_user_id: user_id)

      unless slack_user
        # Create a basic user record if we don't have one
        slack_user = organization.slack_users.create!(slack_user_id: user_id)
        # Enqueue job to fetch their profile
        FetchSlackUserProfileJob.perform_later(organization.id, user_id)
      end

      participants << {
        slack_user_id: user_id,
        name: slack_user.display_name || slack_user.real_name || "Unknown User",
        avatar_url: slack_user.avatar_url,
        email: slack_user.email
      }
    end

    Rails.logger.info "👥 Found #{participants.count} participants"
    participants
  end

  # Gather message statistics per user
  def gather_message_stats(client, channel_id, organization)
    Rails.logger.info "💬 Analyzing message statistics..."

    messages = fetch_all_messages(client, channel_id)

    # Count messages per user
    message_counts = Hash.new(0)
    total_messages = 0

    messages.each do |message|
      user_id = message["user"]
      next if user_id.nil? || user_id.start_with?("B") # Skip bot messages

      # Get user name for display
      slack_user = organization.slack_users.find_by(slack_user_id: user_id)
      user_name = slack_user&.display_name || slack_user&.real_name || user_id

      message_counts[user_name] += 1
      total_messages += 1
    end

    Rails.logger.info "📈 Analyzed #{total_messages} total messages"

    {
      total: total_messages,
      by_user: message_counts.sort_by { |_, count| -count }.to_h # Sort by message count desc
    }
  end

  # Gather shared links and files
  def gather_shared_content(client, channel_id)
    Rails.logger.info "🔗 Gathering shared links and files..."

    messages = fetch_all_messages(client, channel_id)

    links = []
    files = []

    messages.each do |message|
      # Extract links from message text
      if message["text"]
        # Simple URL regex - matches http/https URLs
        urls = message["text"].scan(/https?:\/\/[^\s<>]+/)
        links.concat(urls)
      end

      # Extract files from attachments
      if message["files"]
        message["files"].each do |file|
          files << {
            name: file["name"],
            type: file["filetype"],
            size: file["size"],
            url: file["url_private"],
            shared_by: message["user"]
          }
        end
      end
    end

    Rails.logger.info "🔗 Found #{links.count} links and #{files.count} files"

    {
      links: links.uniq,
      files: files
    }
  end

  # Gather timeline information
  def gather_timeline_info(incident)
    duration = incident.resolved_at - incident.declared_at
    {
      declared: incident.declared_at,
      resolved: incident.resolved_at,
      total_duration: format_duration(duration),
      resolution_speed: categorize_resolution_speed(duration)
    }
  end

  # Fetch all messages from the channel
  def fetch_all_messages(client, channel_id)
    Rails.logger.info "📥 Fetching channel history..."

    all_messages = []
    cursor = nil

    loop do
      response = client.conversations_history({
        channel: channel_id,
        limit: 100,
        cursor: cursor
      }.compact)

      messages = response["messages"] || []
      all_messages.concat(messages)

      cursor = response.dig("response_metadata", "next_cursor")
      break if cursor.blank?

      # Add small delay to be nice to Slack API
      sleep(0.1)
    end

    Rails.logger.info "📥 Fetched #{all_messages.count} messages"
    all_messages
  end

  # Print comprehensive analytics to console
  def print_incident_analytics(analytics)
    puts "\n" + "="*80
    puts "🔥 INCIDENT ANALYTICS REPORT 🔥"
    puts "="*80

    # Incident Overview
    incident = analytics[:incident]
    puts "\n📋 INCIDENT OVERVIEW:"
    puts "   Number: ##{incident[:number]}"
    puts "   Title: #{incident[:title]}"
    puts "   Severity: #{incident[:severity].upcase}"
    puts "   Channel: ##{incident[:channel_name]}"
    puts "   Duration: #{incident[:duration_human]}"
    puts "   Declared: #{incident[:declared_at].strftime('%Y-%m-%d %H:%M:%S')}"
    puts "   Resolved: #{incident[:resolved_at].strftime('%Y-%m-%d %H:%M:%S')}"

    # Participants
    participants = analytics[:participants]
    puts "\n👥 PARTICIPANTS (#{participants.count} total):"
    participants.each do |participant|
      avatar_status = participant[:avatar_url] ? "📸" : "❓"
      puts "   #{avatar_status} #{participant[:name]} (#{participant[:slack_user_id]})"
      puts "      Email: #{participant[:email] || 'Not available'}"
    end

    # Message Statistics
    messages = analytics[:messages]
    puts "\n💬 MESSAGE STATISTICS:"
    puts "   Total Messages: #{messages[:total]}"
    puts "   By User:"
    messages[:by_user].each do |user, count|
      percentage = (count.to_f / messages[:total] * 100).round(1)
      puts "      #{user}: #{count} messages (#{percentage}%)"
    end

    # Links and Files
    content = analytics[:links_and_files]
    puts "\n🔗 SHARED CONTENT:"
    puts "   Links Shared: #{content[:links].count}"
    content[:links].each_with_index do |link, i|
      puts "      #{i+1}. #{link}"
    end

    puts "   Files Shared: #{content[:files].count}"
    content[:files].each_with_index do |file, i|
      puts "      #{i+1}. #{file[:name]} (#{file[:type]}, #{format_file_size(file[:size])})"
    end

    # Timeline
    timeline = analytics[:timeline]
    puts "\n⏱️  TIMELINE:"
    puts "   Resolution Speed: #{timeline[:resolution_speed]}"
    puts "   Total Duration: #{timeline[:total_duration]}"

    puts "\n" + "="*80
    puts "🎯 END OF ANALYTICS REPORT"
    puts "="*80 + "\n"
  end

  # Helper methods
  def format_duration(seconds)
    mm, ss = seconds.divmod(60)
    hh, mm = mm.divmod(60)
    dd, hh = hh.divmod(24)

    parts = []
    parts << "#{dd}d" if dd.positive?
    parts << "#{hh}h" if hh.positive?
    parts << "#{mm}m" if mm.positive?
    parts << "#{ss.to_i}s" if ss.positive? || parts.empty?
    parts.join(" ")
  end

  def categorize_resolution_speed(duration_seconds)
    case duration_seconds
    when 0..300 # 0-5 minutes
      "⚡ Lightning Fast"
    when 301..1800 # 5-30 minutes
      "🚀 Quick Resolution"
    when 1801..3600 # 30-60 minutes
      "👍 Good Response Time"
    when 3601..7200 # 1-2 hours
      "⏰ Standard Resolution"
    else
      "🐌 Extended Resolution"
    end
  end

  def format_file_size(bytes)
    return "0 B" if bytes == 0

    units = %w[B KB MB GB TB]
    base = 1024
    exp = (Math.log(bytes) / Math.log(base)).to_i
    exp = [ exp, units.length - 1 ].min

    "%.1f %s" % [ bytes.to_f / base**exp, units[exp] ]
  end
end

