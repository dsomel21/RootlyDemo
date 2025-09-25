# Sidekiq Configuration
#
# This configures Sidekiq for background job processing.
# Sidekiq uses Redis as a message broker to queue and process jobs.

Sidekiq.configure_server do |config|
  # Redis connection for the Sidekiq server (worker process)
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

Sidekiq.configure_client do |config|
  # Redis connection for the Sidekiq client (Rails app)
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

# Configure Rails to use Sidekiq as the Active Job adapter
Rails.application.config.active_job.queue_adapter = :sidekiq

# Default job options
Sidekiq.default_job_options = {
  "backtrace" => true,  # Include backtrace in job failures for debugging
  "retry" => 3          # Retry failed jobs up to 3 times
}
