class AddRoleIdToUsers < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:users, :role_id)
      add_reference :users, :role, null: true, foreign_key: true
    end
    unless index_exists?(:users, :role_id)
      add_index :users, :role_id
    end
  end
end
