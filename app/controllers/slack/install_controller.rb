class Slack::InstallController < ApplicationController
  # Skip CSRF for install page (external users will hit this)
  skip_before_action :verify_authenticity_token, only: [ :show ]

  def show
    Rails.logger.info "Slack install page accessed from #{request.remote_ip}"

    # Build the Slack OAuth URL
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
      scope: "channels:manage,chat:write,commands,groups:write,users:read",
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
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
          }
          .container {#{' '}
            background: white;#{' '}
            padding: 40px;#{' '}
            border-radius: 16px;#{' '}
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
            width: 100%;
          }
          .logo {#{' '}
            font-size: 48px;#{' '}
            margin-bottom: 16px;#{' '}
          }
          h1 {#{' '}
            color: #1a1a1a;#{' '}
            font-size: 28px;#{' '}
            margin-bottom: 8px;#{' '}
            font-weight: 700;
          }
          .subtitle {#{' '}
            color: #666;#{' '}
            font-size: 16px;#{' '}
            margin-bottom: 32px;#{' '}
            line-height: 1.5;
          }
          .org-info {#{' '}
            background: #f8f9fa;#{' '}
            padding: 20px;#{' '}
            border-radius: 12px;#{' '}
            margin: 24px 0;#{' '}
            border-left: 4px solid #4285f4;
          }
          .org-name {
            font-weight: 600;
            color: #1a1a1a;
            font-size: 18px;
          }
          .org-slug {
            color: #666;
            font-size: 14px;
            margin-top: 4px;
          }
          .install-button {
            display: inline-block;
            background: #4A154B;
            color: white;
            padding: 16px 32px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 600;
            font-size: 16px;
            margin: 24px 0;
            transition: all 0.2s ease;
            border: none;
            cursor: pointer;
          }
          .install-button:hover {
            background: #611f69;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(74, 21, 75, 0.3);
          }
          .slack-logo {
            width: 24px;
            height: 24px;
            margin-right: 8px;
            vertical-align: middle;
          }
          .steps {
            text-align: left;
            margin: 32px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 12px;
          }
          .steps h3 {
            color: #1a1a1a;
            margin-bottom: 16px;
            font-size: 16px;
          }
          .step {
            margin: 8px 0;
            color: #666;
            font-size: 14px;
          }
          .debug-info {
            margin-top: 32px;
            padding: 16px;
            background: #000;
            color: #0f0;
            border-radius: 8px;
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 12px;
            text-align: left;
            overflow-x: auto;
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
            Click to Install Rootly
          </a>

          <div class="steps">
            <h3>What happens next:</h3>
            <div class="step">1️⃣ You'll be redirected to Slack</div>
            <div class="step">2️⃣ Slack will ask "Rootly is requesting permission..."</div>
            <div class="step">3️⃣ Click "Allow" to authorize the app</div>
            <div class="step">4️⃣ You'll be redirected back with success confirmation</div>
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
