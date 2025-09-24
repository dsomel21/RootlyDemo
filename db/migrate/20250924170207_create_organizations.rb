class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :website_url
      t.string :logo_url

      t.timestamps
    end
    
    add_index :organizations, :slug, unique: true
  end
end
