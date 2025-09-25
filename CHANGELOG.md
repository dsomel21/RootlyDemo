# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-01-25

### 🚨 Initial Release - Rootly v1.0

**Simple incident management through Slack**

### ✅ What We Built

#### Rails Application
- Rails 8.0 application with PostgreSQL
- UUID primary keys for multi-tenant architecture
- Active Record encryption for sensitive data
- Service object pattern for business logic

#### Models Created
- `Organization` - Multi-tenant isolation with intelligent slug generation
- `Incident` - Core incident tracking with status/severity enums  
- `SlackUser` - Cached user profiles with avatar support
- `SlackChannel` - Channel-incident relationships
- `SlackInstallation` - OAuth token management
- `IncidentCounter` - Thread-safe sequential incident numbering

#### Core Flow
- Organization can install the app to their workspace via OAuth 2.0
- Requests are cryptographically authenticated using HMAC-SHA256 signature verification
- Users can use `/rootly` command with subcommands
- `/rootly declare <title>` opens Block Kit modal with info pre-filled
- Client + server-side validations in modal. Server errors presented as system issues, not user fault
- Creates `Incident`, `SlackUser`, `SlackChannel` records atomically
- `/rootly resolve` resolves incident in valid incident channels; updates DB and returns resolution time
- Web dashboard with Turbo-powered sorting (title, severity, status, date ASC/DESC)

### Features
- **Slack Integration**: Full OAuth 2.0 flow with secure request verification
- **Incident Declaration**: Interactive modals with rich validation
- **Incident Resolution**: Context-aware resolution with analytics
- **Web Dashboard**: Responsive incident listing with real-time sorting
- **Multi-tenant**: Complete organization isolation
- **Auto-generated Channels**: Dedicated incident workspaces
- **User Profiles**: Automatic Slack profile synchronization

### Technical Highlights
- Hotwire/Turbo for SPA-like experience without JavaScript complexity
- Tailwind CSS for consistent, responsive design
- Service objects for clean business logic separation
- Comprehensive error handling and user feedback
- Thread-safe incident numbering system

### Known Limitations
- Web dashboard lacks authentication (anyone can access `/incidents`)
- Limited integration testing with real Slack API
- Modal close events not handled gracefully

### Next Steps
- Implement web authentication
- Add comprehensive test suite
- Improve user experience flows
- Multi-tenant subdomain architecture
- Enhanced Block Kit designs
