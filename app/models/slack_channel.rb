class SlackChannel < ApplicationRecord
  belongs_to :incident

  validates :slack_channel_id, presence: true
  validates :name, presence: true
  validates :incident_id, uniqueness: true
end
