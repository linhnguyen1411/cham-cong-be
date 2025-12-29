class AddRequestTimeToForgotCheckinRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :forgot_checkin_requests, :request_time, :string # Format: HH:mm (e.g., "08:30", "17:00")
  end
end
