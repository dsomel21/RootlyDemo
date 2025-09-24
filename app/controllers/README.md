# Controllers

This Rails app has two main controller areas:

## Standard Rails Controllers

- `application_controller.rb` - Base controller for web requests

## Slack Integration Controllers

- `slack/` - All Slack-related controllers and logic

👉 **See [slack/README.md](slack/README.md) for detailed documentation on the
Slack integration.**

The Slack controllers handle:

- OAuth app installation
- Slash commands (`/rootly`)
- Interactive components (modals, buttons)
- Request authentication & security
