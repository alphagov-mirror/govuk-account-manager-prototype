class AddNcscPasswordMatchToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :ncsc_password_match, :boolean
  end
end
