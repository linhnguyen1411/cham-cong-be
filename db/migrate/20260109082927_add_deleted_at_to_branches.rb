class AddDeletedAtToBranches < ActiveRecord::Migration[7.1]
  def change
    add_column :branches, :deleted_at, :datetime
    add_index :branches, :deleted_at
  end
end
