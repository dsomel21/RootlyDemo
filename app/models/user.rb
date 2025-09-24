class User < ApplicationRecord
  belongs_to :organization
  has_one :slack_user, dependent: :nullify
  has_many :created_incidents, class_name: "Incident", foreign_key: "creator_id", dependent: :nullify

  validates :name, presence: true
end
