# frozen_string_literal: true

module Incidents
  # Renders the live Slack message notification overlay for active incidents.
  # Displays the latest Slack message inline in the banner's right negative space.
  class LiveSlackNotificationComponent < ApplicationComponent
    def initialize(incident_id:, top_px: "16px", right_px: "20px")
      @incident_id = incident_id
      @top_px = top_px
      @right_px = right_px
    end

    attr_reader :incident_id, :top_px, :right_px

    private

    # Truncates message text to 250 characters for consistent display
    def truncate_message(text)
      return "" if text.blank?

      text.length > 250 ? "#{text[0..246]}..." : text
    end
  end
end
