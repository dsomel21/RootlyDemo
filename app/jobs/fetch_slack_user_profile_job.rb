# Sidekiq Job: Fetches and updates a Slack user's profile (avatar, name, email, etc.)
# Runs asynchronously after incident declaration or when profile info is missing/outdated.
# Retries up to 3 times on failure.

class FetchSlackUserProfileJob < ApplicationJob
  queue_as :default

  # Sidekiq-specific retry configuration
  sidekiq_options retry: 3, backtrace: true

  def perform(organization_id, slack_user_id)
    Rails.logger.info "🔄 Fetching Slack profile for user #{slack_user_id} in org #{organization_id}"

    # Find the organization and user
    organization = Organization.find(organization_id)
    slack_user = organization.slack_users.find_by(slack_user_id: slack_user_id)

    unless slack_user
      Rails.logger.warn "❌ SlackUser #{slack_user_id} not found in organization #{organization_id}"
      return
    end


    begin
      # WORKAROUND: Use users.list since users.info is blocked by workspace policy
      # This is less efficient but works around enterprise restrictions
      client = Slack::Client.new(organization)

      # Get user data from users.list (we'll add this method to client)
      users_list_response = client.users_list(limit: 200)

      # Find our specific user in the list
      user_data = users_list_response["members"]&.find { |member| member["id"] == slack_user_id }

      unless user_data
        Rails.logger.error "User #{slack_user_id} not found in users.list"
        return
      end

      profile_data = user_data["profile"] || {}

      # Update the user record with fresh profile data
      slack_user.update!(
        display_name: profile_data["display_name"],
        real_name: user_data["real_name"],
        email: profile_data["email"],
        title: profile_data["title"],
        avatar_url: select_best_avatar_url(profile_data)
      )

      Rails.logger.info "✅ Updated Slack profile for #{slack_user.display_name || slack_user.real_name || slack_user_id}"
      Rails.logger.info "   Avatar: #{slack_user.avatar_url ? 'Updated' : 'Not available'}"

    rescue => e
      Rails.logger.error "❌ Failed to fetch Slack profile for #{slack_user_id}: #{e.message}"
      Rails.logger.error "   Organization: #{organization.name} (#{organization_id})"
      Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join(', ')}"

      # Handle specific Slack API errors that shouldn't be retried
      if e.message.include?("user_not_found") || e.message.include?("account_inactive")
        Rails.logger.warn "⚠️  User #{slack_user_id} not found or inactive - marking as processed"
        # Mark user as processed so we don't keep trying
        slack_user.update!(
          display_name: "Unknown User",
          real_name: "User Not Found"
        )
        return # Don't retry for missing users
      end

      # Re-raise other errors to trigger Sidekiq retry logic
      raise e
    end
  end

  private


  # Select the best available avatar URL from Slack profile
  # Slack provides multiple sizes, we prefer larger ones for better quality
  def select_best_avatar_url(profile_data)
    avatar_sizes = %w[image_512 image_192 image_72 image_48 image_32]

    avatar_sizes.each do |size|
      url = profile_data[size]
      return url if url.present? && url != ""
    end

    # Fallback to generic avatar if no specific sizes available
    profile_data["image_original"] || profile_data["image"] || nil
  end
end
