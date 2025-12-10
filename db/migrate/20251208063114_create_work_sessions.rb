class CreateWorkSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :work_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :start_time
      t.datetime :end_time
      t.integer :duration_minutes
      t.text :report
      t.string :report_mood
      t.text :handover_notes
      t.json :handover_items, default: [] # Lưu checklist dạng JSON
      t.json :images, default: []         # Lưu mảng ảnh base64 (hoặc URL nếu dùng S3)
      t.string :ip_address
      t.date :date
      t.timestamps
    end
  end
end
