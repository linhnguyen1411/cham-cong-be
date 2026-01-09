class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_system, default: false, null: false
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :roles, :name, unique: true
    add_index :roles, :deleted_at
  end
end
