class AddPositionToWorkShifts < ActiveRecord::Migration[7.1]
  def change
    add_reference :work_shifts, :position, null: true, foreign_key: true
    add_index :work_shifts, :position_id unless index_exists?(:work_shifts, :position_id)
  end
end
