# db/migrate/20251220120000_update_shift_registrations_unique_constraint.rb
class UpdateShiftRegistrationsUniqueConstraint < ActiveRecord::Migration[7.1]
  def up
    # Remove old unique index (user_id, work_date)
    remove_index :shift_registrations, name: 'idx_shift_reg_user_date' if index_exists?(:shift_registrations, [:user_id, :work_date], name: 'idx_shift_reg_user_date')
    
    # Add new unique index (user_id, work_date, work_shift_id)
    # Cho phép nhiều ca trong 1 ngày, nhưng không được trùng ca
    add_index :shift_registrations, [:user_id, :work_date, :work_shift_id], 
              unique: true, 
              name: 'idx_shift_reg_user_date_shift'
  end

  def down
    # Remove new index
    remove_index :shift_registrations, name: 'idx_shift_reg_user_date_shift' if index_exists?(:shift_registrations, [:user_id, :work_date, :work_shift_id], name: 'idx_shift_reg_user_date_shift')
    
    # Restore old unique index
    add_index :shift_registrations, [:user_id, :work_date], 
              unique: true, 
              name: 'idx_shift_reg_user_date'
  end
end

