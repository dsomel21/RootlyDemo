class Slack::InstallController < ApplicationController
  # Skip CSRF for install page (external users will hit this)
  skip_before_action :verify_authenticity_token, only: [ :show ]

  # GET /slack/install
  #
  # Displays the "Add to Slack" installation page that initiates OAuth flow.
  #
  # OAuth Flow:
  # 1. User clicks "Add to Slack" → redirected to Slack with our client_id
  # 2. User grants permissions → Slack redirects to our oauth/callback with code
  # 3. Our callback exchanges code for tokens → creates Organization record
  #
  # URL Parameters Passed to Slack:
  # - client_id: Identifies our app
  # - scope: Permissions we need (commands, chat:write, etc.)
  # - redirect_uri: Where Slack sends user after authorization
  # - state: CSRF protection token
  #
  # @return [void] Renders HTML page with OAuth button
  def show
    @slack_oauth_url = build_slack_oauth_url
    @callback_url = url_for(controller: "slack/oauth", action: "callback", only_path: false)

    render_install_page
  end

  private

  def build_slack_oauth_url
    callback_url = Rails.application.credentials.slack[:redirect_url] ||
                   url_for(controller: "slack/oauth", action: "callback", only_path: false)

    params = {
      client_id: Rails.application.credentials.slack[:client_id],
      scope: "commands,chat:write,chat:write.public,channels:read,channels:manage,channels:join,groups:read,groups:write,users:read,users:read.email,channels:history,groups:history,im:history,mpim:history,pins:read,pins:write,files:read,links:read",
      redirect_uri: callback_url,
      state: generate_state_token
    }

    "https://slack.com/oauth/v2/authorize?#{params.to_query}"
  end

  def generate_state_token
    payload = {
      install_session: SecureRandom.hex(16),
      timestamp: Time.current.to_i
    }

    Base64.urlsafe_encode64(payload.to_json)
  end

  # 📌 TODO: Let's redo this with Vue or something later
  def render_install_page
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Install Rootly for Slack</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {#{' '}
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #000000 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            position: relative;
            margin: 0;
          }
          body::before {
            content: '';
            position: absolute;
            inset: 0;
            background: linear-gradient(to right, rgba(139, 92, 246, 0.3) 1px, transparent 1px),
                        linear-gradient(to bottom, rgba(139, 92, 246, 0.3) 1px, transparent 1px);
            background-size: 20px 20px;
            opacity: 0.1;
            pointer-events: none;
          }
          .container {#{' '}
            background: linear-gradient(135deg, rgba(30, 41, 59, 0.9) 0%, rgba(15, 23, 42, 0.9) 100%);
            backdrop-filter: blur(12px);
            border: 1px solid rgba(139, 92, 246, 0.3);
            padding: 48px;#{' '}
            border-radius: 24px;#{' '}
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.05);
            text-align: center;
            max-width: 1200px;
            width: 100%;
            position: relative;
            z-index: 1;
            margin: 0 auto;
          }
          .logo {#{' '}
            font-size: 64px;#{' '}
            margin-bottom: 24px;#{' '}
            filter: drop-shadow(0 0 20px rgba(139, 92, 246, 0.5));
          }
          h1 {#{' '}
            color: #ffffff;#{' '}
            font-size: 32px;#{' '}
            margin-bottom: 12px;#{' '}
            font-weight: 700;
            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
          }
          .subtitle {#{' '}
            color: #c4b5fd;#{' '}
            font-size: 18px;#{' '}
            margin-bottom: 40px;#{' '}
            line-height: 1.6;
            font-weight: 400;
          }
          .org-info {#{' '}
            background: linear-gradient(135deg, rgba(139, 92, 246, 0.1) 0%, rgba(79, 70, 229, 0.1) 100%);
            border: 1px solid rgba(139, 92, 246, 0.2);
            padding: 24px;#{' '}
            border-radius: 16px;#{' '}
            margin: 32px 0;#{' '}
            border-left: 4px solid #8b5cf6;
            backdrop-filter: blur(8px);
          }
          .org-name {
            font-weight: 600;
            color: #ffffff;
            font-size: 20px;
            margin-bottom: 8px;
          }
          .org-slug {
            color: #a78bfa;
            font-size: 16px;
            font-weight: 400;
          }
          .install-button {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
            color: white;
            padding: 20px 40px;
            border-radius: 12px;
            text-decoration: none;
            font-weight: 600;
            font-size: 18px;
            margin: 32px 0;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            border: none;
            cursor: pointer;
            box-shadow: 0 8px 25px rgba(139, 92, 246, 0.4);
            position: relative;
            overflow: hidden;
            outline: none;
            user-select: none;
            animation: pulse-glow 3s ease-in-out infinite;
          }
          .install-button::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            transition: left 0.6s ease;
          }
          .install-button::after {
            content: '';
            position: absolute;
            inset: 0;
            background: linear-gradient(135deg, rgba(255, 255, 255, 0.1) 0%, transparent 50%);
            opacity: 0;
            transition: opacity 0.3s ease;
          }
          .install-button:hover {
            background: linear-gradient(135deg, #7c3aed 0%, #6d28d9 100%);
            transform: translateY(-3px) scale(1.02);
            box-shadow: 0 15px 40px rgba(139, 92, 246, 0.6), 0 0 0 1px rgba(255, 255, 255, 0.1);
            animation: none;
          }
          .install-button:hover::before {
            left: 100%;
          }
          .install-button:hover::after {
            opacity: 1;
          }
          .install-button:active {
            transform: translateY(-1px) scale(0.98);
            box-shadow: 0 8px 20px rgba(139, 92, 246, 0.8);
            background: linear-gradient(135deg, #6d28d9 0%, #5b21b6 100%);
            transition: all 0.1s ease;
          }
          .install-button:focus {
            outline: 2px solid rgba(139, 92, 246, 0.5);
            outline-offset: 2px;
            box-shadow: 0 8px 25px rgba(139, 92, 246, 0.4), 0 0 0 4px rgba(139, 92, 246, 0.2);
          }
          .install-button:focus:not(:focus-visible) {
            outline: none;
          }
          @keyframes pulse-glow {
            0%, 100% {
              box-shadow: 0 8px 25px rgba(139, 92, 246, 0.4);
            }
            50% {
              box-shadow: 0 8px 25px rgba(139, 92, 246, 0.4), 0 0 20px rgba(139, 92, 246, 0.3);
            }
          }
          .slack-logo {
            width: 28px;
            height: 28px;
            margin-right: 12px;
            vertical-align: middle;
          }
          .steps {
            margin: 48px 0;
            text-align: center;
          }
          .steps h3 {
            color: #ffffff;
            margin-bottom: 40px;
            font-size: 24px;
            font-weight: 700;
            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
          }
          .steps-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px;
            margin-top: 32px;
          }
          @media (max-width: 1024px) {
            .steps-grid {
              grid-template-columns: repeat(2, 1fr);
              gap: 24px;
            }
          }
          @media (max-width: 640px) {
            .steps-grid {
              grid-template-columns: 1fr;
              gap: 20px;
            }
          }
          .step-card {
            background: linear-gradient(135deg, rgba(30, 41, 59, 0.8) 0%, rgba(15, 23, 42, 0.8) 100%);
            border: 1px solid rgba(139, 92, 246, 0.3);
            border-radius: 20px;
            padding: 28px 20px;
            backdrop-filter: blur(12px);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
            text-align: center;
            min-height: 200px;
            display: flex;
            flex-direction: column;
            justify-content: center;
          }
          .step-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, #8b5cf6, #7c3aed, #6d28d9);
            opacity: 0;
            transition: opacity 0.3s ease;
          }
          .step-card:hover {
            transform: translateY(-4px);
            border-color: rgba(139, 92, 246, 0.5);
            box-shadow: 0 20px 40px rgba(139, 92, 246, 0.2);
          }
          .step-card:hover::before {
            opacity: 1;
          }
          .step-number {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 56px;
            height: 56px;
            background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 50%, #6d28d9 100%);
            border-radius: 16px;
            color: white;
            font-size: 20px;
            font-weight: 800;
            margin-bottom: 20px;
            box-shadow:#{' '}
              0 8px 25px rgba(139, 92, 246, 0.4),
              0 0 0 1px rgba(255, 255, 255, 0.1),
              inset 0 1px 0 rgba(255, 255, 255, 0.2);
            position: relative;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            border: 2px solid transparent;
            background-clip: padding-box;
          }
          .step-number::before {
            content: '';
            position: absolute;
            inset: -2px;
            background: linear-gradient(135deg, #8b5cf6, #7c3aed, #6d28d9, #5b21b6);
            border-radius: 18px;
            z-index: -1;
            opacity: 0;
            transition: opacity 0.3s ease;
            animation: gradient-rotate 3s linear infinite;
          }
          .step-number::after {
            content: '';
            position: absolute;
            inset: 0;
            background: linear-gradient(135deg, rgba(255, 255, 255, 0.1) 0%, transparent 50%);
            border-radius: 14px;
            opacity: 0;
            transition: opacity 0.3s ease;
          }
          .step-card:hover .step-number {
            transform: translateY(-2px) scale(1.05);
            box-shadow:#{' '}
              0 12px 35px rgba(139, 92, 246, 0.6),
              0 0 0 1px rgba(255, 255, 255, 0.2),
              inset 0 1px 0 rgba(255, 255, 255, 0.3);
          }
          .step-card:hover .step-number::before {
            opacity: 1;
          }
          .step-card:hover .step-number::after {
            opacity: 1;
          }
          @keyframes gradient-rotate {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
          .step-title {
            color: #ffffff;
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 10px;
            line-height: 1.4;
          }
          .step-description {
            color: #c4b5fd;
            font-size: 14px;
            line-height: 1.5;
            font-weight: 400;
          }
          .debug-info {
            margin-top: 40px;
            padding: 20px;
            background: linear-gradient(135deg, rgba(0, 0, 0, 0.8) 0%, rgba(15, 23, 42, 0.8) 100%);
            border: 1px solid rgba(139, 92, 246, 0.3);
            color: #10b981;
            border-radius: 12px;
            font-family: 'Monaco', 'Menlo', 'SF Mono', monospace;
            font-size: 13px;
            text-align: left;
            overflow-x: auto;
            backdrop-filter: blur(8px);
          }
          .debug-info strong {
            color: #8b5cf6;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="logo">🚨</div>
          <h1>Install Rootly for Slack</h1>
          <p class="subtitle">Connect your Slack workspace to manage incidents like a pro</p>
      #{'    '}
          <div class="org-info">
            <div class="org-name">Ready to Install</div>
            <div class="org-slug">We'll create your organization during the setup process</div>
          </div>

          <a href="#{@slack_oauth_url}" class="install-button">
            <svg class="slack-logo" viewBox="0 0 24 24" fill="currentColor">
              <path d="M5.042 15.165a2.528 2.528 0 0 1-2.52 2.523A2.528 2.528 0 0 1 0 15.165a2.527 2.527 0 0 1 2.522-2.52h2.52v2.52zM6.313 15.165a2.527 2.527 0 0 1 2.521-2.52 2.527 2.527 0 0 1 2.521 2.52v6.313A2.528 2.528 0 0 1 8.834 24a2.528 2.528 0 0 1-2.521-2.522v-6.313zM8.834 5.042a2.528 2.528 0 0 1-2.521-2.52A2.528 2.528 0 0 1 8.834 0a2.528 2.528 0 0 1 2.521 2.522v2.52H8.834zM8.834 6.313a2.528 2.528 0 0 1 2.521 2.521 2.528 2.528 0 0 1-2.521 2.521H2.522A2.528 2.528 0 0 1 0 8.834a2.528 2.528 0 0 1 2.522-2.521h6.312zM18.956 8.834a2.528 2.528 0 0 1 2.522-2.521A2.528 2.528 0 0 1 24 8.834a2.528 2.528 0 0 1-2.522 2.521h-2.522V8.834zM17.688 8.834a2.528 2.528 0 0 1-2.523 2.521 2.527 2.527 0 0 1-2.52-2.521V2.522A2.527 2.527 0 0 1 15.165 0a2.528 2.528 0 0 1 2.523 2.522v6.312zM15.165 18.956a2.528 2.528 0 0 1 2.523 2.522A2.528 2.528 0 0 1 15.165 24a2.527 2.527 0 0 1-2.52-2.522v-2.522h2.52zM15.165 17.688a2.527 2.527 0 0 1-2.52-2.523 2.526 2.526 0 0 1 2.52-2.52h6.313A2.527 2.527 0 0 1 24 15.165a2.528 2.528 0 0 1-2.522 2.523h-6.313z"/>
            </svg>
            Install Rootly for Slack
          </a>

          <div class="steps">
            <h3>What happens next:</h3>
            <div class="steps-grid">
              <div class="step-card">
                <div class="step-number">1</div>
                <div class="step-title">Redirect to Slack</div>
                <div class="step-description">You'll be taken to Slack's authorization page where you can review the permissions</div>
              </div>
              <div class="step-card">
                <div class="step-number">2</div>
                <div class="step-title">Review Permissions</div>
                <div class="step-description">Slack will show you what Rootly needs access to in your workspace</div>
              </div>
              <div class="step-card">
                <div class="step-number">3</div>
                <div class="step-title">Authorize Installation</div>
                <div class="step-description">Click "Allow" to grant Rootly access to your Slack workspace</div>
              </div>
              <div class="step-card">
                <div class="step-number">4</div>
                <div class="step-title">Success!</div>
                <div class="step-description">You'll be redirected back with a confirmation that Rootly is now installed</div>
              </div>
            </div>
          </div>

          <div class="debug-info">
            <strong>🔍 Debug Info:</strong><br>
            OAuth URL: #{@slack_oauth_url}<br>
            Callback: #{@callback_url}<br>
            Timestamp: #{Time.current}
          </div>
        </div>
      </body>
      </html>
    HTML

    render html: html_content.html_safe
  end
end
