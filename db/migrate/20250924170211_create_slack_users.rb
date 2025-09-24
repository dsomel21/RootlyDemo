class CreateSlackUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_users, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :slack_user_id, null: false
      t.string :display_name
      t.string :real_name
      t.string :avatar_url
      t.references :user, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end
    
    add_index :slack_users, [:organization_id, :slack_user_id], unique: true
  end
end
