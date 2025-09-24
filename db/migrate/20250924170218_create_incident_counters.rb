class CreateIncidentCounters < ActiveRecord::Migration[8.0]
  def change
    create_table :incident_counters, id: false do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid, primary_key: true
      t.integer :last_number, default: 0

      t.timestamps
    end
  end
end
