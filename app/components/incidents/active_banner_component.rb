# frozen_string_literal: true

module Incidents
  # Renders the prominent banner that highlights the most recent active incident.
  # Encapsulates the countdown timer setup so future changes stay localised here.
  class ActiveBannerComponent < ApplicationComponent
    with_collection_parameter :incident

    def initialize(incident:)
      @incident = incident
    end

    attr_reader :incident

    def slack_channel
      incident.slack_channel
    end

    def slack_creator
      incident.slack_creator
    end

    def timer_start_iso
      incident.declared_at&.iso8601
    end

    def active_statuses
      IndexComponent::ACTIVE_STATUSES
    end
  end
end
