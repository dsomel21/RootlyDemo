# Incidents Controller
#
# This controller handles displaying and managing incidents in the web UI.
# It includes Turbo-powered sorting functionality for a smooth user experience.
#
# TURBO EXPLANATION:
# Turbo is part of the Hotwire stack that allows us to build interactive web apps
# without writing JavaScript. It works by intercepting form submissions and link clicks,
# making AJAX requests, and updating parts of the page with the response.
#
# Key Turbo concepts used here:
# 1. Turbo Frames: Named sections of HTML that can be updated independently
# 2. Turbo Stream: Server-sent instructions to update multiple parts of the page
# 3. data-turbo-method: Specify HTTP method for links (GET, POST, etc.)
# 4. turbo_frame_tag: Creates a frame that can be targeted for updates

class IncidentsController < ApplicationController
  before_action :set_sorting_params, only: [ :index ]

  # GET /incidents
  #
  # TURBO FLOW EXPLANATION:
  # 1. Initial page load: Renders full HTML page with incidents list
  # 2. Sort link clicked: Turbo intercepts the click, makes AJAX request
  # 3. Server responds with HTML fragment (just the incidents_list frame)
  # 4. Turbo replaces the old frame content with new sorted content
  # 5. URL updates in browser without full page reload
  # 6. User sees smooth transition with no page flash
  def index
    @incidents = fetch_sorted_incidents
    @active_incidents = @incidents.active

    # TURBO FRAME RESPONSE:
    # When a Turbo Frame makes a request, Rails automatically detects it
    # and will only render the matching turbo_frame_tag from the view.
    # This means we can use the same action for both full page loads
    # and partial updates - Rails handles the difference automatically!

    respond_to do |format|
      format.html # Full page for initial load
      # Turbo automatically handles frame requests - no extra code needed!
    end
  end

  # GET /incidents/:id
  # GET /incidents/:slug
  def show
    id_or_slug = params[:id] || params[:slug]

    # Try to find by UUID first (pure UUID format: 69eb53f0-7e55-4039-a10f-cbf144474066)
    if id_or_slug.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      @incident = Incident.find(id_or_slug)
    else
      # Try to find by slug (format: title-uuid-uuid)
      # Split on hyphen and take last 5 parts (UUID components split by hyphens)
      slug_parts = id_or_slug.split("-")
      if slug_parts.length >= 5
        # Extract UUID from slug (last 5 hyphenated parts)
        uuid = slug_parts.last(5).join("-")
        @incident = Incident.find(uuid)
      else
        raise ActiveRecord::RecordNotFound
      end
    end
  end

  private

  # Extract and validate sorting parameters from the request
  #
  # TURBO SORTING FLOW:
  # 1. User clicks "Sort by Title ↑" link
  # 2. Link contains params like ?sort=title&direction=asc
  # 3. Turbo makes AJAX request with these params
  # 4. This method processes the params
  # 5. fetch_sorted_incidents uses them to order the query
  # 6. View renders with new sort indicators
  def set_sorting_params
    @sort_column = params[:sort].presence&.to_sym || :created_at
    @sort_direction = params[:direction].presence&.to_sym || :desc

    # Validate sort column to prevent SQL injection
    allowed_columns = [ :title, :severity, :status, :created_at, :number ]
    @sort_column = :created_at unless allowed_columns.include?(@sort_column)

    # Validate direction
    @sort_direction = :desc unless [ :asc, :desc ].include?(@sort_direction)

    Rails.logger.info "Sorting by #{@sort_column} #{@sort_direction}"
  end

  # Fetch incidents with applied sorting
  #
  # PERFORMANCE NOTE:
  # We're including related models (organization, slack_creator) to avoid N+1 queries
  # This is important when rendering lists with associated data
  def fetch_sorted_incidents
    # Start with base query including associations
    query = Incident.includes(:organization, :slack_creator, :slack_channel)

    # Apply sorting based on column type
    case @sort_column
    when :title
      # String sorting - case insensitive
      # Use Arel.sql with safe interpolation to avoid SQL injection
      if @sort_direction == :asc
        query = query.order(Arel.sql("LOWER(title) ASC"))
      else
        query = query.order(Arel.sql("LOWER(title) DESC"))
      end
    when :severity
      # Enum sorting - convert to integer for proper ordering
      # sev0 = 0 (highest), sev1 = 1, sev2 = 2 (lowest)
      query = query.order(severity: @sort_direction)
    when :status
      # Enum sorting
      query = query.order(status: @sort_direction)
    when :number
      # Integer sorting
      query = query.order(number: @sort_direction)
    else
      # Default: created_at (timestamp)
      query = query.order(created_at: @sort_direction)
    end

    # Add secondary sort to ensure consistent ordering
    query = query.order(id: :desc) unless @sort_column == :created_at

    query
  end

  # Helper method to generate sort URLs for the view.
  # Example:
  #   sort_url(:title)    #=> /incidents?sort=title&direction=asc
  #   sort_url(:severity) #=> /incidents?sort=severity&direction=desc
  def sort_url(column)
    direction = (@sort_column == column.to_sym && @sort_direction == :asc) ? :desc : :asc

    incidents_path(sort: column, direction: direction)
  end
  helper_method :sort_url

  # Helper to determine if a column is currently being sorted
  def sorted_by?(column)
    @sort_column == column.to_sym
  end
  helper_method :sorted_by?

  # Helper to get sort direction for display (arrows)
  def sort_direction_for(column)
    return nil unless sorted_by?(column)
    @sort_direction
  end
  helper_method :sort_direction_for
end
