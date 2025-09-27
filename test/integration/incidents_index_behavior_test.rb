require "test_helper"

class IncidentsIndexBehaviorTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)

    # Create test incidents with different statuses and timestamps
    @resolved_incident = Incident.create!(
      organization: @organization,
      title: "Resolved Database Issue",
      number: 1,
      severity: :sev1,
      status: :resolved,
      declared_at: 2.hours.ago,
      resolved_at: 1.hour.ago
    )

    @investigating_incident = Incident.create!(
      organization: @organization,
      title: "Active Network Outage",
      number: 2,
      severity: :sev0,
      status: :investigating,
      declared_at: 2.hours.ago # This will be over 1 hour old
    )

    @recent_incident = Incident.create!(
      organization: @organization,
      title: "Recent Service Degradation",
      number: 3,
      severity: :sev2,
      status: :resolved,
      declared_at: 30.minutes.ago
    )
  end

  test "shows no active incident banner when all incidents are resolved" do
    # Mark all incidents as resolved
    @investigating_incident.update!(status: :resolved, resolved_at: Time.current)
    @recent_incident.update!(status: :resolved, resolved_at: Time.current)

    get incidents_path

    assert_response :success
    assert_select "h1", text: "🚨 Incidents Dashboard"

    # Should not show active incident banner
    assert_select "span", text: "ACTIVE INCIDENT", count: 0

    # Should show incidents list
    assert_select "h3", text: "Incidents List"
    assert_select "span", text: "Total: 3 incidents"
  end

  test "shows active incident banner when there is an active incident" do
    get incidents_path

    assert_response :success

    # Should show active incident banner for the oldest active incident
    assert_select "span", text: "ACTIVE INCIDENT"
    assert_select "h2", text: "#2 — Active Network Outage" # Should show the oldest active incident

    # Should show "Ongoing for" text with timer
    assert_select "p", text: /Ongoing for/
    assert_select "time[data-start-iso]", count: 1

    # Extract the timer start ISO and verify it's correct
    timer_element = css_select("time[data-start-iso]").first
    timer_start_iso = timer_element["data-start-iso"]
    timer_start_time = Time.parse(timer_start_iso)

    # The timer should start from declared_at time
    assert_equal @investigating_incident.declared_at.to_i, timer_start_time.to_i
  end

  test "shows help message when no incidents exist at all" do
    # Delete all incidents
    Incident.destroy_all

    get incidents_path

    assert_response :success
    assert_select "h1", text: "🚨 Incidents Dashboard"

    # Should not show active incident banner
    assert_select "span", text: "ACTIVE INCIDENT", count: 0

    # Should show empty state with help message
    assert_select "h3", text: "No incidents found"
    assert_select "p", text: /Get started by creating your first incident through Slack/
    assert_select "code", text: "/rootly declare <title>"

    # Should show 0 incidents count
    assert_select "span", text: "Total: 0 incidents"
  end

  test "shows timer in 1:xx format for incidents over 1 hour old" do
    # Create an incident that's exactly 1 hour and 30 minutes old
    old_incident = Incident.create!(
      organization: @organization,
      title: "Old Incident",
      number: 4,
      severity: :sev1,
      status: :investigating,
      declared_at: (1.hour + 30.minutes).ago
    )

    # Make this the only active incident by resolving others
    @investigating_incident.update!(status: :resolved, resolved_at: Time.current)
    @recent_incident.update!(status: :resolved, resolved_at: Time.current)

    get incidents_path

    assert_response :success

    # Should show the old incident in the banner
    assert_select "h2", text: "#4 — Old Incident"
    assert_select "p", text: /Ongoing for/

    # The JavaScript timer should show 1:30:xx format
    # We can't directly test the JavaScript execution, but we can verify
    # the timer element is present with correct data attribute
    timer_element = css_select("time[data-start-iso]").first
    assert_not_nil timer_element

    timer_start_iso = timer_element["data-start-iso"]
    timer_start_time = Time.parse(timer_start_iso)

    # Verify the timer starts from the declared_at time (within 1 second tolerance)
    assert_in_delta old_incident.declared_at.to_i, timer_start_time.to_i, 1

    # The initial text should show time duration
    timer_text = timer_element.text
    assert_match(/about \d+ hours?|over \d+ hours?|hours?/, timer_text)
  end

  test "resolving active incident removes banner from page" do
    # Resolve all other incidents first to have only one active incident
    @recent_incident.update!(status: :resolved, resolved_at: Time.current)

    # Start with an active incident
    get incidents_path

    assert_response :success
    assert_select "span", text: "ACTIVE INCIDENT"
    assert_select "h2", text: "#2 — Active Network Outage"

    # Resolve the active incident
    @investigating_incident.update!(status: :resolved, resolved_at: Time.current)

    # Refresh the page
    get incidents_path

    assert_response :success

    # Banner should no longer be present
    assert_select "span", text: "ACTIVE INCIDENT", count: 0

    # Should show incidents list without banner
    assert_select "h3", text: "Incidents List"
    assert_select "span", text: "Total: 3 incidents"

    # The resolved incident should still be in the list
    assert_select "h2", text: "#2 — Active Network Outage", count: 0 # Not in banner
    # Should appear in the incidents list instead
  end


  test "displays correct incident count in header" do
    get incidents_path

    assert_response :success

    # Should show total count of all incidents (active + resolved)
    assert_select "span", text: "Total: 3 incidents"

    # Create another incident
    Incident.create!(
      organization: @organization,
      title: "Another Incident",
      number: 6,
      severity: :sev2,
      status: :monitoring,
      declared_at: Time.current
    )

    get incidents_path

    assert_response :success
    assert_select "span", text: "Total: 4 incidents"
  end

  test "handles edge case of incident declared exactly 1 hour ago" do
    # Create incident declared exactly 1 hour ago
    exact_hour_incident = Incident.create!(
      organization: @organization,
      title: "Exactly 1 Hour Ago",
      number: 7,
      severity: :sev1,
      status: :investigating,
      declared_at: 1.hour.ago
    )

    # Make this the only active incident
    @investigating_incident.update!(status: :resolved, resolved_at: Time.current)
    @recent_incident.update!(status: :resolved, resolved_at: Time.current)

    get incidents_path

    assert_response :success

    # Should show the incident in banner
    assert_select "h2", text: "#7 — Exactly 1 Hour Ago"
    assert_select "p", text: /Ongoing for/

    # Timer should show 1:00:xx format
    timer_element = css_select("time[data-start-iso]").first
    assert_not_nil timer_element

    timer_start_iso = timer_element["data-start-iso"]
    timer_start_time = Time.parse(timer_start_iso)

    # Verify the timer starts from the declared_at time (within 1 second tolerance)
    assert_in_delta exact_hour_incident.declared_at.to_i, timer_start_time.to_i, 1
  end

  test "shows Join Slack Channel when incident has associated slack channel" do
    # Create a slack channel for the investigating incident
    slack_channel = @investigating_incident.create_slack_channel!(
      slack_channel_id: "C1234567890",
      name: "incident-channel"
    )

    # Make sure we have only one active incident
    @recent_incident.update!(status: :resolved, resolved_at: Time.current)

    get incidents_path

    assert_response :success

    # Should show "Join #incident-channel" text in the banner
    assert_select "a", text: "Join #incident-channel"

    # Should not show "No Slack Channel" text
    assert_select "div", text: "No Slack Channel", count: 0
  end
end
