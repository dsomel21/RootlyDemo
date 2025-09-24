# Slack Integration Controllers

Anything that's related to Slack, is put in the `/slack`/`Slack::` namespace!

## Overview

```
User visits /slack/install → install_controller.rb → OAuth flow
User types /rootly → commands_controller.rb → Opens modal
User submits modal → interactions_controller.rb → Processes form
```

## Core Controllers

### `install_controller.rb` 🚀

**Purpose**: Displays the "Add to Slack" installation page that starts the OAuth
flow.

**What it does**:

- Shows a button that says "Add to Slack"
- Builds OAuth URL with your `client_id`, `scope`, `redirect_uri`, and `state`
- Redirects users to Slack for authorization

**Key Endpoint**:

- `GET /slack/install` - Installation landing page

### `base_controller.rb` 🔐

**Purpose**: Shared authentication and security for all Slack endpoints.

**Key Features**:

- **Request verification** using
  [Slack's signature verification](https://docs.slack.dev/authentication/verifying-requests-from-slack)
- **Organization lookup** based on Slack team ID
- **Before action** that authenticates every request automatically

**Security**: Uses HMAC-SHA256 cryptographic signatures to ensure requests
actually come from Slack.

### `oauth_controller.rb` 📱

**Purpose**: Handles the OAuth installation flow when users add the app to their
Slack workspace.

**The OAuth Handshake** (Staff-level explanation for Juniors):

1. **User clicks "Add to Slack"** on our install page
2. **Slack redirects** user to `slack.com/oauth/v2/authorize` with our app's
   `client_id`
3. **User authorizes** our app (clicks "Allow")
4. **Slack redirects back** to our `oauth/callback` endpoint with a temporary
   `code`
5. **Our server exchanges** the `code` for permanent tokens by calling
   `slack.com/api/oauth.v2.access`
6. **Slack returns**:
   - `access_token` (bot token for API calls)
   - `team.id` (identifies the workspace)
   - `team.name` (workspace name)
7. **We store** the tokens and create an `Organization` + `SlackInstallation`
   record
8. **Installation complete** - our app can now receive commands from that
   workspace

**Security Notes**:

- The `code` expires quickly (10 minutes)
- The `state` parameter prevents CSRF attacks
- Bot tokens are encrypted at rest using Rails credentials

**Key Endpoints**:

- `GET /slack/oauth/callback` - Receives the OAuth callback from Slack

### `commands_controller.rb` & `interactions_controller.rb` ⚡

**Purpose**: Handle user interactions

**Flow**:

1. User types `/rootly declare "Something"` → `commands_controller.rb`
2. User interacts with modal/buttons → `interactions_controller.rb`

## Configuration Required

### Slack App Settings

Configure these URLs in your Slack app settings:

```
OAuth Redirect URL: https://your-domain.com/slack/oauth/callback
Slash Commands URL: https://your-domain.com/slack/commands  
Interactivity URL:  https://your-domain.com/slack/interactions
```

For now, use Local Tunnel

### Rails Credentials

Store sensitive keys using `rails credentials:edit`:

```yaml
slack:
   client_id: "123456789.123456789"
   client_secret: "your-client-secret"
   signing_secret: "your-signing-secret"
   redirect_url: "https://your-domain.com/slack/oauth/callback" # Use a localtunnel URL for now
```

## Security & Authentication

All Slack requests are verified using the pattern described in
[Slack's documentation](https://docs.slack.dev/authentication/verifying-requests-from-slack):
