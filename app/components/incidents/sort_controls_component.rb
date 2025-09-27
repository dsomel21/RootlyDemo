# frozen_string_literal: true

module Incidents
  # Encapsulates the “Sort by” pill controls so the layout component stays tidy.
  # The component relies on controller helpers (sort_url, sorted_by?, etc.), so
  # it simply delegates back up to ViewComponent (which has access to helpers).
  class SortControlsComponent < ApplicationComponent
    SORT_COLUMNS = %i[title severity status created_at].freeze

    delegate :sort_url, :sorted_by?, :sort_direction_for, to: :helpers

    def sort_links
      SORT_COLUMNS
    end

    def label_for(column)
      column == :created_at ? "Created" : column.to_s.titleize
    end
  end
end
