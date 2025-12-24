# db/migrate/20251220100004_add_forgot_checkout_to_work_sessions.rb
class AddForgotCheckoutToWorkSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :work_sessions, :forgot_checkout, :boolean, default: false
    add_column :work_sessions, :shift_registration_id, :bigint
    add_index :work_sessions, :shift_registration_id
    add_foreign_key :work_sessions, :shift_registrations, column: :shift_registration_id
  end
end

