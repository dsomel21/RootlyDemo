# frozen_string_literal: true

module Incidents
  # Represents a single `incident` card in the list. Each card is rendered from
  # `Incidents::IncidentListComponent`, which loops through all `incidents` on
  # the `incidents#index` page.
  class IncidentCardComponent < ApplicationComponent
    def initialize(incident:)
      @incident = incident
    end

    attr_reader :incident

    # @return [String] Tailwind border class for emphasising severity.
    # The template applies this to the outer card `<div>`.
    def severity_border
      case incident.severity
      when "sev0" then "border-red-500"
      when "sev1" then "border-orange-500"
      else "border-yellow-500"
      end
    end

    # @return [String] Tailwind classes for the severity badge background.
    # Consumed by the severity pill `<span>`.
    def severity_pill_class
      case incident.severity
      when "sev0"
        "bg-gradient-to-r from-red-500/20 to-red-600/20 text-red-200 border-red-400/50"
      when "sev1"
        "bg-gradient-to-r from-orange-500/20 to-orange-600/20 text-orange-200 border-orange-400/50"
      else
        "bg-gradient-to-r from-yellow-500/20 to-yellow-600/20 text-yellow-200 border-yellow-400/50"
      end
    end

    # @return [String] Tailwind classes for the status badge.
    def status_pill_class
      case incident.status
      when "resolved"
        "bg-gradient-to-r from-green-500/20 to-green-600/20 text-green-200 border-green-400/50"
      when "monitoring"
        "bg-gradient-to-r from-blue-500/20 to-blue-600/20 text-blue-200 border-blue-400/50"
      when "identified"
        "bg-gradient-to-r from-purple-500/20 to-purple-600/20 text-purple-200 border-purple-400/50"
      else
        "bg-gradient-to-r from-gray-500/20 to-gray-600/20 text-gray-200 border-gray-400/50"
      end
    end

    # @return [String] Text for the CTA button shown on the right side.
    # Resolved incidents encourage reviewing the postmortem; others link to the incident.
    def contextual_cta
      incident.status == "resolved" ? "Review Postmortem" : "Open Incident"
    end

    # @return [String] Initial used when the Slack avatar is missing.
    # NOTE: This assumes that the creator of the incident is ALWAYS the commander.
    # Displayed in the "Team" avatar group.
    def commander_initial
      incident.slack_creator&.display_name&.first || "U"
    end

    # @return [String, nil] Human-readable time-to-resolution if the incident is resolved.
    # Rendered in the metadata footer of the card.
    def duration_text
      return unless incident.status == "resolved" && incident.declared_at && incident.resolved_at

      duration_seconds = incident.resolved_duration_seconds
      hours = duration_seconds / 3600
      minutes = (duration_seconds % 3600) / 60

      if hours.positive?
        "#{hours}h #{minutes}m"
      elsif minutes.positive?
        "#{minutes}m"
      else
        "<1m"
      end
    end
  end
end
