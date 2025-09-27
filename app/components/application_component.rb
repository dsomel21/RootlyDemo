# frozen_string_literal: true

# Base class for ViewComponents in this app. Centralise helper inclusions so
# individual components stay focused on their own logic.
class ApplicationComponent < ViewComponent::Base
  include Turbo::FramesHelper
end
