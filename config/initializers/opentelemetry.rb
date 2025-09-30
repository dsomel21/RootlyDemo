#------------------------------------------------------------------------------
# OpenTelemetry setup for Rails
#
# This initializer configures the OpenTelemetry SDK to auto-instrument
# Rails, ActiveRecord, and other libraries, and export telemetry to
# Grafana Cloud via the OTLP endpoint defined in ENV.

# Required ENVs:
# * OTEL_SERVICE_NAME
# * OTEL_EXPORTER_OTLP_ENDPOINT
# * OTEL_EXPORTER_OTLP_HEADERS: Authorization=Bearer glc_...
#------------------------------------------------------------------------------
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "rootly-demo")

  # Configure the OTLP exporter
  exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
    endpoint: ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT"),
    headers: {
      "Authorization" => ENV.fetch("OTEL_EXPORTER_OTLP_HEADERS")
    }
  )

  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter)
  )

  # Auto-instrument common libraries
  c.use_all
end
