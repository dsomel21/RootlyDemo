# Rootly Clone Demo (Take Home Assignment)

Watch the demo
[here](https://www.loom.com/share/419c3c1761f14e64b6a47a1887d96860?sid=68ba0baf-dbbc-4e4c-9b63-72613a1adcd5)!

Hi! My name is Dilraj! I'm a hardcore softare dev... and I also love using,
studying, building amazing products. This is the Rootly clone I made (as a part
of the Product Engineering coding assignment).

## How It Works

- Team installs the app to their Slack workspac (`/slack/install`)
- They go to Slack, type the `/rootly declare <title>` command to declare an
  incident
- They fill out a modal form to declare the incident (`title`, `description`,
  and `severity`)
- The system creates a dedicated incident channel, updates metadata, syncs user
  profiles, and tracks everything in a web dashboard (`incidents#index`)
- When the incident is resolved, they use `/rootly resolve` to close it out and
  get analytics on response time and team participation

## Technical Architecture

### General

It's a Rails-y monolith and I tried to follow the standard Rails conventions and
patterns.

- Ruby on Rails
- PostgreSQL
- Sidekiq + Redis
- HTML + ERB
- Hotwire/Turbo
- Stimulus
- Tailwind CSS
- ViewComponent

### Service Objects

Business logic is encapsulated in plain Ruby objects within `app/services/`. I
did this to keep the controllers thin...

I intionally went with this _Workflow_ design, because... the way I think about
Rootly's domain is inherently a sequence of coordinated steps and
side-effects.... When you `/rootly declare <title>` or `/rootly resolve`, it's
not just one update... it can trigger:

- DB read/writes
- Changes in Slack
- Analytics jobs
- Calendar updates
- Ticket transitions
- Delayed follow-ups

...there is a big benefit to encapsulating that in a single orchestrator, I keep
the logic explicit, testable, and domain-driven.

It’s lightweight today—just a plain Ruby object (without retries, durable
state)—but it gives us a clean contract for when we `declare` or `resolve` an
incident. That means we can easily layer in events, async fan-out, or
policy-based branching as Rootly evolves...

Key services:

- `Slack::Workflows::DeclareCommand` - Handles incident declaration flow
- `Slack::Workflows::ResolveIncidentCommand` - Manages incident resolution
- `Slack::Client` - Wrapper for Slack API interactions

### Asynchronous Processing

Background jobs handle non-blocking operations using Sidekiq:

- `FetchSlackUserProfileJob` - Syncs user profiles after incident creation
- `EpicAnalyticsImageJob` - Generates post-resolution analytics visualizations
- `UpdateSlackChannelMetadataJob` - Updates channel metadata

### Cloudinary Integration

Analytics visualizations are generated as SVG and uploaded to Cloudinary for:

- Dynamic image generation with user avatars
- Automatic PNG conversion for Slack compatibility
- CDN delivery for fast image loading

### Real-time Updates

Live Slack notifications use polling with Intersection Observer API:

- 8-second polling intervals for new messages (I could've optimized this to be
  more efficient, but I was worried it would mess up the demo lol)
- Visibility-based polling (stops when element not in view). (Room for
  improvement, see
  [here](https://github.com/dsomel21/RootlyDemo/blob/bd3158a5e474c7a93a172d3630255d5140470102/app/javascript/controllers/live_slack_controller.js#L20-L21))

### Controller Architecture

Controllers follow Rails conventions with Slack-specific namespacing. All Slack
endpoints live in the `Slack::` namespace with thin controllers that delegate
business logic to service objects. Shared authentication and organization lookup
is handled by `Slack::BaseController`.

## Setup

### Prerequisites

1. Slack API Keys
2. Cloudinary API Keys
3. Setup your environment variables. I run
   `EDITOR="nano" bin/rails credentials:edit` and then update them here:

```
secret_key_base: abc123

active_record_encryption:
  primary_key: abc123
  key_derivation_salt: abc123

slack:
  client_id: abc123
  client_secret: abc123
  signing_secret: abc123
  redirect_url: abc123 # This needs to be a valid HTTPS url. I used `localtunnel` for this

cloudinary:
  cloud_name: abc123
  api_key: abc123
  api_secret: abc123
  url: abc123
```

1. Install dependencies: `bundle install`
2. Setup database: `rails db:setup`
3. Start server: `rails server`
4. Start Sidekiq: `sidekiq` or `bundle exec sidekiq` (in a separate terminal)

### Code Quality

```bash
bundle exec rubocop
bundle exec rubocop --autocorrect
```

### Background Jobs

```bash
bundle exec sidekiq
```

Monitor jobs at `/sidekiq` endpoint.

## Testing

Integration tests cover complete workflows from HTTP requests through
controllers, services, and database changes.

```bash
rails test
rails test test/integration/slack_incident_declare_workflow_test.rb
```

## Other Documentation

- Controllers: [app/controllers/README.md](app/controllers/README.md)

I also tried to add some documentation to the codebase, around complex parts...
