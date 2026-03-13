class CreateManagerJoinTables < ActiveRecord::Migration[7.1]
  def change
    # branch_managers: nhiều user có thể quản lý cùng 1 chi nhánh
    create_table :branch_managers do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :branch_managers, [:branch_id, :user_id], unique: true

    # department_managers: nhiều user có thể quản lý cùng 1 khối
    create_table :department_managers do |t|
      t.references :department, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :department_managers, [:department_id, :user_id], unique: true

    # position_managers: nhiều user có thể quản lý cùng 1 vị trí
    create_table :position_managers do |t|
      t.references :position, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :position_managers, [:position_id, :user_id], unique: true

    # Migrate existing manager_id data vào join tables
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO branch_managers (branch_id, user_id, created_at, updated_at)
          SELECT id, manager_id, NOW(), NOW()
          FROM branches
          WHERE manager_id IS NOT NULL
          ON CONFLICT (branch_id, user_id) DO NOTHING;

          INSERT INTO department_managers (department_id, user_id, created_at, updated_at)
          SELECT id, manager_id, NOW(), NOW()
          FROM departments
          WHERE manager_id IS NOT NULL
          ON CONFLICT (department_id, user_id) DO NOTHING;

          INSERT INTO position_managers (position_id, user_id, created_at, updated_at)
          SELECT id, manager_id, NOW(), NOW()
          FROM positions
          WHERE manager_id IS NOT NULL
          ON CONFLICT (position_id, user_id) DO NOTHING;
        SQL
      end
    end
  end
end
