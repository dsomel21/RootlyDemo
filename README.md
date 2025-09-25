# Rootly

A Rails application that integrates with Slack to manage incidents.

## Overview

Rootly provides incident management through Slack slash commands and interactive
modals. Users can declare and resolve incidents directly from their Slack
workspace.

## Key Features

- **Slack Integration**: OAuth app installation and slash commands
- **Incident Management**: Declare incidents with `/rootly declare <title>`
- **Organization Support**: Multi-tenant with workspace isolation

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
