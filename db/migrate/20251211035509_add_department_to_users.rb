class AddDepartmentToUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :department, null: true, foreign_key: true
  end
end
