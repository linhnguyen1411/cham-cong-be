class AddDeletedAtToPositions < ActiveRecord::Migration[7.1]
  def change
    add_column :positions, :deleted_at, :datetime
    add_index :positions, :deleted_at
  end
end
