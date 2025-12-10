class AddShiftToWorkSessions < ActiveRecord::Migration[7.1]
  def change
    add_reference :work_sessions, :work_shift, foreign_key: true, null: true
  end
end
