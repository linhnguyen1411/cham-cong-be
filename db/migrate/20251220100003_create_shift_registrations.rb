# db/migrate/20251220100003_create_shift_registrations.rb
class CreateShiftRegistrations < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_registrations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :work_shift, null: false, foreign_key: true
      t.date :work_date, null: false              # Ngày làm việc cụ thể
      t.date :week_start, null: false             # Ngày bắt đầu tuần (để group)
      t.integer :status, default: 0               # 0: pending, 1: approved, 2: rejected
      t.text :note                                # Ghi chú từ nhân viên
      t.text :admin_note                          # Ghi chú từ admin
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      
      t.timestamps
    end
    
    # Mỗi nhân viên chỉ đăng ký 1 ca cho mỗi ngày
    add_index :shift_registrations, [:user_id, :work_date], unique: true, name: 'idx_shift_reg_user_date'
    add_index :shift_registrations, :week_start
    add_index :shift_registrations, :status
  end
end

