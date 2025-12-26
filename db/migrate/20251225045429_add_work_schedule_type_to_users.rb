class AddWorkScheduleTypeToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :work_schedule_type, :integer, default: 0, null: false
    # 0 = both_shifts (2 ca), 1 = morning_only (chỉ ca sáng), 2 = afternoon_only (chỉ ca chiều)
  end
end
