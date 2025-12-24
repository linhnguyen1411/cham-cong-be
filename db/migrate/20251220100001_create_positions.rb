# db/migrate/20251220100001_create_positions.rb
class CreatePositions < ActiveRecord::Migration[7.1]
  def change
    create_table :positions do |t|
      t.string :name, null: false
      t.text :description
      t.references :branch, foreign_key: true
      t.references :department, foreign_key: true
      t.integer :level, default: 0  # 0: staff, 1: team lead, 2: manager, etc.
      
      t.timestamps
    end
    
    add_index :positions, [:name, :branch_id, :department_id], unique: true, name: 'idx_positions_unique'
  end
end

