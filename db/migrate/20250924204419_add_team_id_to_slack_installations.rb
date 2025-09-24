class AddTeamIdToSlackInstallations < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_installations, :team_id, :string, null: false
    add_index :slack_installations, :team_id, unique: true
  end
end
