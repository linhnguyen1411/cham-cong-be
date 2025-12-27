class AddShiftRegistrationLimitsToAppSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :app_settings, :max_user_off_days_per_week, :integer, default: 1, null: false
    add_column :app_settings, :max_user_off_shifts_per_week, :integer, default: 2, null: false
    add_column :app_settings, :max_shift_off_count_per_day, :integer, default: 1, null: false
  end
end
