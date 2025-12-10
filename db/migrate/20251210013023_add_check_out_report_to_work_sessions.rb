class AddCheckOutReportToWorkSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :work_sessions, :work_summary, :text, null: true
    add_column :work_sessions, :challenges, :text, null: true
    add_column :work_sessions, :suggestions, :text, null: true
    add_column :work_sessions, :notes, :text, null: true
  end
end
