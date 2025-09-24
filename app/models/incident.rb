class Incident < ApplicationRecord
  belongs_to :organization
  belongs_to :slack_creator, class_name: "SlackUser", optional: true
  belongs_to :creator, class_name: "User", optional: true
  has_one :slack_channel, dependent: :destroy

  enum severity: { sev0: 0, sev1: 1, sev2: 2 }
  enum status: { investigating: 0, identified: 1, monitoring: 2, resolved: 3 }

  validates :title, presence: true
  validates :number, presence: true
  validates :number, uniqueness: { scope: :organization_id }
  validates :declared_at, presence: true
  validates :status, presence: true

  validate :resolved_at_after_declared_at

  private

  def resolved_at_after_declared_at
    return unless resolved_at && declared_at

    errors.add(:resolved_at, "must be after declared_at") if resolved_at < declared_at
  end
end
