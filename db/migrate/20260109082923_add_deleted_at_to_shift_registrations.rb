class AddDeletedAtToShiftRegistrations < ActiveRecord::Migration[7.1]
  def change
    add_column :shift_registrations, :deleted_at, :datetime
    add_index :shift_registrations, :deleted_at
  end
end
