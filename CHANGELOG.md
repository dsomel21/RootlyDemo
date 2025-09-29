# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2025-01-25

### 🚀 Major Release - Rootly v2.0

**Enhanced incident management with real-time updates and analytics**

### ✨ What's New

#### Real-time Slack Integration
- **Live Slack Notifications**: Real-time polling of Slack messages in incident channels
- **Intersection Observer API**: Smart polling that stops when dashboard is not visible
- **8-second polling intervals**: Efficient real-time updates without overwhelming the API
- **LiveSlackNotificationComponent**: ViewComponent for seamless integration

#### Advanced Analytics & Visualizations
- **Epic Analytics Image Generation**: Post-resolution analytics with visual summaries
- **Cloudinary Integration**: Dynamic SVG generation converted to PNG for Slack compatibility
- **User Avatar Integration**: Personalized analytics with team member photos
- **Resolution Time Tracking**: Detailed metrics on incident response times

#### Enhanced User Experience
- **Modern Dark Frontend**: Complete UI overhaul with dark theme
- **ViewComponent Architecture**: Modular, reusable components for better maintainability
- **Improved Install Page**: Better onboarding experience with updated design
- **Mobile-Friendly Design**: Responsive layouts optimized for all devices
- **Enhanced Slack Channel Management**: Automatic metadata updates and descriptions

#### Background Job System
- **EpicAnalyticsImageJob**: Generates comprehensive analytics visualizations
- **PostUserProfileMessageJob**: Automated user profile synchronization
- **UpdateSlackChannelMetadataJob**: Keeps channel information current
- **Sidekiq Integration**: Robust background processing with Redis

#### Code Quality & Architecture
- **Service Object Pattern**: Clean separation of business logic
- **Comprehensive Testing**: Integration tests covering complete workflows
- **Security Improvements**: Fixed SQL injection vulnerabilities
- **Better Error Handling**: Graceful error management throughout the application
- **Documentation**: Enhanced code comments and README updates

### 🔧 Technical Improvements
- **Hotwire/Turbo**: SPA-like experience with minimal JavaScript
- **Stimulus Controllers**: Enhanced JavaScript functionality
- **Tailwind CSS**: Consistent, responsive design system
- **PostgreSQL**: Robust data persistence with UUID primary keys
- **Active Record Encryption**: Secure handling of sensitive data

### 🐛 Bug Fixes
- Fixed SQL injection vulnerability in incidents sorting
- Improved modal copy and user messaging
- Enhanced input validation throughout the application
- Better error handling for Slack API interactions

### 📚 Documentation
- Updated README with comprehensive setup instructions
- Enhanced code comments and inline documentation
- Better controller documentation in `app/controllers/README.md`

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
