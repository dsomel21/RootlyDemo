class SlackInstallation < ApplicationRecord
  belongs_to :organization

  encrypts :bot_access_token_ciphertext
  encrypts :signing_secret_ciphertext

  validates :bot_access_token_ciphertext, presence: true
  validates :signing_secret_ciphertext, presence: true
end
