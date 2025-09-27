# frozen_string_literal: true

module Incidents
  # Wraps the incident list grid (including empty state). Each individual card
  # is rendered by Incidents::IncidentCardComponent so card layout tweaks stay
  # focused and testable in isolation.
  class IncidentListComponent < ApplicationComponent
    def initialize(incidents:)
      @incidents = incidents
    end

    attr_reader :incidents

    def incidents?
      incidents.any?
    end
  end
end
