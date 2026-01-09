class AddDeletedAtToWorkSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :work_sessions, :deleted_at, :datetime
    add_index :work_sessions, :deleted_at
  end
end
