class Slack::InteractionsController < Slack::BaseController
  # POST /slack/interactions

  def receive
    puts "🚀 SLACK INTERACTION RECEIVED: #{params[:type]}"
  end
end
