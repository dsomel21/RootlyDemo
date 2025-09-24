class SlackInstallation < ApplicationRecord
  belongs_to :organization

  encrypts :bot_access_token_ciphertext
  encrypts :signing_secret_ciphertext

  validates :team_id, presence: true, uniqueness: true
  validates :bot_access_token_ciphertext, presence: true
  validates :signing_secret_ciphertext, presence: true

  # Find installation by team_id for incoming Slack requests
  def self.find_by_team(team_id)
    find_by(team_id: team_id)
  end
end
