class AddEarlyCheckoutToWorkSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :work_sessions, :is_early_checkout, :boolean, default: false
    add_column :work_sessions, :minutes_before_end, :integer, default: 0
  end
end
