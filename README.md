# 🚨 Rootly v1.0

**Simple incident management through Slack**

Rootly is a Rails-based incident management platform that integrates seamlessly with Slack. Teams can declare, track, and resolve incidents without leaving their communication workflow, while maintaining a centralized web dashboard for incident oversight.

## ✨ Key Features

### Slack-Native Incident Management
- **`/rootly declare <title>`**: Interactive Block Kit modals with rich validation
- **`/rootly resolve`**: Context-aware incident resolution with analytics
- **Automated Channels**: Dedicated incident workspaces (`#inc-0001-database-issues`)
- **User Profiles**: Automatic Slack profile synchronization

### Web Dashboard
- **Incident Listing**: Comprehensive overview with Turbo-powered sorting
- **Real-time Sorting**: Sort by title, severity, status, date (ASC/DESC)
- **Rich Metadata**: Creator info, resolution times, Slack channel links
- **Responsive Design**: Mobile-optimized with Tailwind CSS

### Multi-Tenant Architecture
- **Organization Isolation**: Complete data separation using UUIDs
- **OAuth 2.0 Security**: Secure app installation with encrypted token storage
- **Request Verification**: HMAC-SHA256 signature validation
- **Sequential Numbering**: Thread-safe incident counters per organization

## Documentation

- **Controllers**: [app/controllers/README.md](app/controllers/README.md)
- **Slack Integration**:
  [app/controllers/slack/README.md](app/controllers/slack/README.md)

## Setup

1. Install dependencies: `bundle install`
2. Setup database: `rails db:setup`
3. Configure Slack credentials: `rails credentials:edit`
4. Start server: `rails server`

## Development

- **Ruby version**: Check `.ruby-version`
- **Database**: PostgreSQL
- **External tunneling**: Use localtunnel for Slack webhooks

### Code Quality

Run the linter to check code style:

```bash
bundle exec rubocop
```

Auto-fix most issues:

```bash
bundle exec rubocop --autocorrect
```

Run tests:

```bash
rails test
```
