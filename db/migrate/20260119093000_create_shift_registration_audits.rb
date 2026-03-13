class CreateShiftRegistrationAudits < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_registration_audits do |t|
      t.string  :action, null: false # 'deleted', 'restored', ...
      t.bigint  :actor_id, null: true
      t.bigint  :target_user_id, null: true
      t.bigint  :shift_registration_id, null: true
      t.bigint  :work_shift_id, null: true
      t.date    :work_date, null: true
      t.date    :week_start, null: true
      t.string  :previous_status, null: true
      t.string  :source, null: true # 'admin_quick_delete', 'bulk_create_cleanup', ...
      t.text    :reason, null: true
      t.jsonb   :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :shift_registration_audits, :week_start
    add_index :shift_registration_audits, :work_date
    add_index :shift_registration_audits, :actor_id
    add_index :shift_registration_audits, :target_user_id
    add_index :shift_registration_audits, :work_shift_id
    add_index :shift_registration_audits, :shift_registration_id

    add_foreign_key :shift_registration_audits, :users, column: :actor_id
    add_foreign_key :shift_registration_audits, :users, column: :target_user_id
    add_foreign_key :shift_registration_audits, :work_shifts, column: :work_shift_id
    add_foreign_key :shift_registration_audits, :shift_registrations, column: :shift_registration_id
  end
end


