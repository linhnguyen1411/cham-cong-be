class AddDeletedAtToForgotCheckinRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :forgot_checkin_requests, :deleted_at, :datetime
    add_index :forgot_checkin_requests, :deleted_at
  end
end
