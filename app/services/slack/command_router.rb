module Slack
  class CommandRouter
    def self.route(text)
      case text.to_s.strip
      when /^declare\s+(.+)/i
        { action: :declare, title: $1.strip }
      when /^resolve$/i
        { action: :resolve }
      else
        { action: :help }
      end
    end
  end
end
