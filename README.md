# 🚨 Rootly v1.0

**Simple incident management through Slack**

RootlyDemo is [Dilraj](https://www.linkedin.com/in/dilraj-singh-468771169/)'s
attempt at building a minified Rootly! This is a Rails-based incident management
platform that integrates seamlessly with Slack. Teams can declare, track, and
resolve incidents without leaving their communication workflow, while
maintaining a centralized web dashboard for incident oversight.

## ✨ Key Features

### Slack-Native Incident Management

- `/rootly declare <title>`: Interactive Block Kit modals with rich validation
- `/rootly resolve`: Context-aware incident resolution with analytics
- Automated Channels: Dedicated incident workspaces
  (`#inc-0001-database-issues`)
- User Profiles: Automatic Slack profile synchronization

### Web Dashboard

- Incident Listing: Comprehensive overview with Turbo-powered sorting
- Real-time Sorting: Sort by title, severity, status, date (ASC/DESC)
- Rich Metadata: Creator info, resolution times, Slack channel links
- Responsive Design: Mobile-optimized with Tailwind CSS

### Multi-Tenant Architecture

- Organization Isolation: Complete data separation using UUIDs
- OAuth 2.0 Security: Secure app installation with encrypted token storage
- Request Verification: HMAC-SHA256 signature validation
- Sequential Numbering: Thread-safe incident counters per organization

## Documentation

- Controllers: [app/controllers/README.md](app/controllers/README.md)
- Slack Integration:
  [app/controllers/slack/README.md](app/controllers/slack/README.md)

## Setup

1. Install dependencies: `bundle install`
2. Setup database: `rails db:setup`
3. Configure Slack credentials: `rails credentials:edit`
4. Start server: `rails server`

## Development

- Ruby version: Check `.ruby-version`
- Database: PostgreSQL
- External tunneling: Use localtunnel for Slack webhooks

### Code Quality

Run the linter to check code style:

```bash
bundle exec rubocop
```

Auto-fix most issues:

```bash
bundle exec rubocop --autocorrect
```

## Sidekiq

We use Sidekiq for background jobs to keep the Slack interactions snappy. Here's
what runs in the background:

- `FetchSlackUserProfileJob`: Grabs user avatars, names, emails after incident
  creation
- `PostUserProfileMessageJob`: Posts rich profile cards to incident channels
- `EpicAnalyticsImageJob`: Builds the post-resolution analytics visualization

To run Sidekiq locally:

```bash
bundle exec sidekiq
```

Debug/Monitor:

- Dashboard: Visit `/sidekiq` in your browser (shows queues, jobs, failures)
- Logs: Sidekiq logs appear in your Rails console
- Failed Jobs: Check the "Dead" tab in dashboard to retry failed jobs

## Tests

Philosophy: Test the whole damn workflow, not tiny pieces. We test real HTTP
requests → controllers → services → database changes.

Run all tests:

```bash
rails test
```

Run specific test:

```bash
rails test test/integration/slack_incident_declare_workflow_test.rb
```

Run single test method:

```bash
rails test test/integration/slack_incident_declare_workflow_test.rb -n test_successful_declare_command
```

Pro tip: Tests automatically run in CI/CD on every push. Green build = good to
deploy.
