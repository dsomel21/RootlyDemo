class CreateSlackChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_channels, id: :uuid do |t|
      t.references :incident, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.string :slack_channel_id, null: false
      t.string :name, null: false

      t.timestamps
    end
  end
end
