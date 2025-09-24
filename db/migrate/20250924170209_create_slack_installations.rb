class CreateSlackInstallations < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_installations, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.string :bot_user_id
      t.text :bot_access_token_ciphertext, null: false
      t.text :signing_secret_ciphertext, null: false

      t.timestamps
    end
  end
end
