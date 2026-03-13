class AddManagerToPositions < ActiveRecord::Migration[7.1]
  def change
    # Thêm manager_id vào positions (quản lý phòng ban/vị trí)
    add_reference :positions, :manager, null: true, foreign_key: { to_table: :users }, index: true unless column_exists?(:positions, :manager_id)
  end
end
