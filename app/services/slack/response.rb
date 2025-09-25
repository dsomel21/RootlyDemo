module Slack
  class Response
    attr_reader :json, :status, :ok
    def initialize(json = {}, status: 200, ok: true)
      @json, @status, @ok = json, status, ok
    end
    def self.ok(json = {}, status: 200)  = new(json, status:, ok: true)
    def self.err(text, status: 200)      = new({ response_type: "ephemeral", text: text }, status:, ok: false)
  end
end
