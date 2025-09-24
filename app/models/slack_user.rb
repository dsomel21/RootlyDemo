class SlackUser < ApplicationRecord
  belongs_to :organization
  belongs_to :user, optional: true
  has_many :slack_created_incidents, class_name: "Incident", foreign_key: "slack_creator_id", dependent: :nullify

  validates :slack_user_id, presence: true
  validates :slack_user_id, uniqueness: { scope: :organization_id }
end
