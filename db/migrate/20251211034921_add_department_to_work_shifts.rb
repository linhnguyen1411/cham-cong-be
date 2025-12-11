class AddDepartmentToWorkShifts < ActiveRecord::Migration[7.1]
  def change
    add_reference :work_shifts, :department, null: true, foreign_key: true
  end
end
