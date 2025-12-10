class CreateAppSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :app_settings do |t|
      t.string :company_name
      t.boolean :require_ip_check, default: true
      t.json :allowed_ips, default: [] # Lưu mảng IP
      t.timestamps
    end
  end
end
