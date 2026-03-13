class AddManagerToDepartmentsAndBranches < ActiveRecord::Migration[7.1]
  def change
    # Thêm manager_id vào departments
    add_reference :departments, :manager, null: true, foreign_key: { to_table: :users }, index: true unless column_exists?(:departments, :manager_id)
    
    # Thêm manager_id vào branches
    add_reference :branches, :manager, null: true, foreign_key: { to_table: :users }, index: true unless column_exists?(:branches, :manager_id)
  end
end
