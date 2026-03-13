class MakeShiftRegistrationsUniqueIndexSoftDeleteSafe < ActiveRecord::Migration[7.1]
  def up
    # Existing index blocks re-creating a registration after soft delete because deleted rows still collide.
    if index_exists?(:shift_registrations, [:user_id, :work_date, :work_shift_id], name: 'idx_shift_reg_user_date_shift')
      remove_index :shift_registrations, name: 'idx_shift_reg_user_date_shift'
    end

    # Enforce uniqueness only among active (non-deleted) registrations.
    add_index :shift_registrations,
              [:user_id, :work_date, :work_shift_id],
              unique: true,
              name: 'idx_shift_reg_user_date_shift',
              where: "deleted_at IS NULL"
  end

  def down
    if index_exists?(:shift_registrations, [:user_id, :work_date, :work_shift_id], name: 'idx_shift_reg_user_date_shift')
      remove_index :shift_registrations, name: 'idx_shift_reg_user_date_shift'
    end

    add_index :shift_registrations,
              [:user_id, :work_date, :work_shift_id],
              unique: true,
              name: 'idx_shift_reg_user_date_shift'
  end
end


