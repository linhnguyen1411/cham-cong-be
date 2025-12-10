class CreateWorkShifts < ActiveRecord::Migration[7.1]
  def change
    create_table :work_shifts do |t|
      t.string :name, null: false
      t.string :start_time, null: false  # Format: "HH:mm" e.g., "08:00"
      t.string :end_time, null: false    # Format: "HH:mm" e.g., "17:00"
      t.integer :late_threshold, default: 30  # minutes
      t.timestamps
    end
    
    add_index :work_shifts, :name, unique: true
  end
end
