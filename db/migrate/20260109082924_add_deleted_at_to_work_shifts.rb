class AddDeletedAtToWorkShifts < ActiveRecord::Migration[7.1]
  def change
    add_column :work_shifts, :deleted_at, :datetime
    add_index :work_shifts, :deleted_at
  end
end
