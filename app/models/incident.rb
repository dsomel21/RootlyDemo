class Incident < ApplicationRecord
  belongs_to :organization
  belongs_to :slack_creator, class_name: "SlackUser", optional: true
  belongs_to :creator, class_name: "User", optional: true
  has_one :slack_channel, dependent: :destroy

  enum :severity, { sev0: 0, sev1: 1, sev2: 2 }
  enum :status, { investigating: 0, identified: 1, monitoring: 2, resolved: 3 }

  validates :title, presence: true
  validates :number, presence: true
  validates :number, uniqueness: { scope: :organization_id }
  validates :declared_at, presence: true
  validates :status, presence: true

  validate :resolved_at_after_declared_at

  ACTIVE_STATUSES = %w[investigating identified monitoring].freeze

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  class << self
    # @return [Array<String>] statuses that constitute an active (unresolved) incident.
    def active_statuses
      ACTIVE_STATUSES
    end
  end

  # @return [Boolean] true when the incident is still in-flight (pre-resolved).
  def active?
    self.class.active_statuses.include?(status)
  end

  ##
  # Computes incident analytics using Slack conversation history.
  #
  # This is a heavy function and may incur significant latency,
  # as it must fetch the entire message history and participant user profiles
  # from the related Slack channel via the Slack API.
  #
  # @return [Hash] analytics data for the incident's Slack conversation
  # @raise [RuntimeError] if the incident does not have an associated Slack channel
  def gather_slack_analytics
    raise "Incident has no slack channel" unless self.slack_channel

    human_messages = self.slack_channel.fetch_slack_history.reject { |msg| msg["bot_profile"].present? }
    participant_stats = gather_participants_from_messages(human_messages)
    message_stats = summarize_messages(human_messages, participant_stats[:slack_users])
    link_stats, file_stats = gather_shared_content(human_messages)
    quote = pick_quote(human_messages, participant_stats[:slack_users])

    {
      participants: participant_stats[:slack_users],
      messages: message_stats,
      links: link_stats,
      files: file_stats,
      quote: quote
    }
  end

  # @return [Integer] seconds between declare and resolve (e.g. 3600)
  def resolved_duration_seconds
    return 0 unless resolved_at && declared_at

    (resolved_at - declared_at).to_i
  end

  # Generate a URL-friendly slug for the incident
  # Example: "Database down" becomes "database-down-uuid"
  def slug
    title_parameterized = title.parameterize(preserve_case: :lower, separator: "-")
    "#{title_parameterized}-#{id}"
  end

  private

  def resolved_at_after_declared_at
    return unless resolved_at && declared_at
    errors.add(:resolved_at, "must be after declared_at") if resolved_at < declared_at
  end

  # Extracts participant SlackUsers from the message history.
  # NOTE: Performs HTTP lookups for missing users and may enqueue FetchSlackUserProfileJob.
  # @return [Hash] e.g. { slack_users: [#<SlackUser ...>] }
  def gather_participants_from_messages(messages)
    ids = messages.map { |msg| msg["user"] }.compact.uniq

    existing_users = organization.slack_users.where(slack_user_id: ids).index_by(&:slack_user_id)
    missing_ids = ids - existing_users.keys

    # The odd case where we need to create a new `SlackUser`
    missing_ids.each do |slack_id|
      new_user = organization.slack_users.create!(slack_user_id: slack_id)
      FetchSlackUserProfileJob.perform_later(organization.id, slack_id)
      existing_users[slack_id] = new_user
    end

    { slack_users: existing_users.values }
  end

  # Summarizes message totals and per-user counts.
  # @return [Hash] e.g. { total: 12, by_user: {"Jane"=>5}, by_id: {"U1"=>5} }
  def summarize_messages(messages, slack_users)
    counts = Hash.new(0)
    counts_by_id = Hash.new(0)
    id_to_user = slack_users.index_by(&:slack_user_id)
    total = 0

    messages.each do |message|
      next if message["bot_profile"].present?
      user_id = message["user"]
      next if user_id.nil?

      total += 1
      user = id_to_user[user_id]
      name = user&.display_name.presence || user&.real_name.presence || user_id
      counts[name] += 1
      counts_by_id[user_id] += 1
    end

    {
      total: total,
      by_user: counts.sort_by { |_, count| -count }.to_h,
      by_id: counts_by_id
    }
  end

  # Returns [links, files] arrays extracted from message history.
  # @return [Array<Array>] e.g. [["https://root.ly"], [{name: "log.txt", ...}]]
  def gather_shared_content(messages)
    links = []
    files = []

    messages.each do |message|
      text = message["text"]
      links.concat(text.scan(/https?:\/\/[^\s<>]+/)) if text

      Array(message["files"]).each do |file|
        files << {
          name: file["name"],
          type: file["filetype"],
          size: file["size"],
          url: file["url_private"],
          shared_by: file["user"]
        }
      end
    end

    [ links.uniq, files ]
  end

  # Chooses a sanitized quote shorter than 100 characters.
  # @return [Hash, nil] e.g. { text: "We got this", author: "Jane" }
  def pick_quote(messages, slack_users)
    id_to_user = slack_users.index_by(&:slack_user_id)

    candidates = messages.filter_map do |message|
      next if message["bot_profile"].present?
      user_id = message["user"]
      next if user_id.nil?

      text = message["text"].to_s.strip
      next if text.blank? || text.length > 100

      user = id_to_user[user_id]
      {
        text: text,
        author: user&.display_name.presence || user&.real_name.presence || user&.slack_user_id || "Unknown Hero"
      }
    end

    candidates.sample
  end
end
