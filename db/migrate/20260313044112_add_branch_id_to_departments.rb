class AddBranchIdToDepartments < ActiveRecord::Migration[7.1]
  def change
    add_column :departments, :branch_id, :bigint
  end
end
