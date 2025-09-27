# frozen_string_literal: true

module Incidents
  # This component is responsible for rendering the grid of incident cards,
  # as well as displaying the empty state when there are no incidents.
  #
  # Each incident card is rendered using the Incidents::IncidentCardComponent,
  # allowing card-specific layout and logic to remain encapsulated and easily testable.
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
