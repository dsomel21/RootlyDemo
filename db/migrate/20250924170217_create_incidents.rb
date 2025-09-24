class CreateIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :incidents, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :description
      t.integer :number, null: false
      t.integer :severity
      t.integer :status, null: false, default: 0
      t.references :slack_creator, null: true, foreign_key: { to_table: :slack_users }, type: :uuid
      t.references :creator, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :declared_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :incidents, [ :organization_id, :number ], unique: true
    add_check_constraint :incidents, "resolved_at IS NULL OR resolved_at >= declared_at", name: "resolved_at_after_declared_at"
  end
end
