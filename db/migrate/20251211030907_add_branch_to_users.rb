class AddBranchToUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :branch, null: true, foreign_key: true
    add_column :users, :work_address, :string
  end
end
