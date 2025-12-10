class AddIsOnTimeToWorkSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :work_sessions, :is_on_time, :boolean, default: nil
    add_column :work_sessions, :minutes_late, :integer, default: 0
  end
end
