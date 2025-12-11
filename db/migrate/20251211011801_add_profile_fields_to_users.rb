class AddProfileFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :address, :string unless column_exists?(:users, :address)
    add_column :users, :phone, :string unless column_exists?(:users, :phone)
    add_column :users, :birthday, :date unless column_exists?(:users, :birthday)
    # avatar_url removed - using Active Storage has_one_attached :avatar instead
  end
end
