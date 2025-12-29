class CreateForgotCheckinRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :forgot_checkin_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.date :request_date, null: false
      t.string :request_type, null: false # 'checkin' hoặc 'checkout'
      t.text :reason, null: false
      t.string :status, default: 'pending' # 'pending', 'approved', 'rejected'
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.text :rejected_reason

      t.timestamps
    end
    
    add_index :forgot_checkin_requests, :status
    add_index :forgot_checkin_requests, :request_date
    add_index :forgot_checkin_requests, [:user_id, :request_date, :request_type], name: 'index_forgot_checkin_requests_unique'
  end
end
