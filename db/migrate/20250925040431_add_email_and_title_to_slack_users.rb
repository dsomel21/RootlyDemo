class AddEmailAndTitleToSlackUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :slack_users, :email, :string
    add_column :slack_users, :title, :string
  end
end
