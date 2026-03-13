class AddIsSuperAdminToRoles < ActiveRecord::Migration[7.1]
  def change
    add_column :roles, :is_super_admin, :boolean, default: false, null: false
    
    # Set is_super_admin for existing super_admin role
    execute <<-SQL
      UPDATE roles SET is_super_admin = true WHERE name = 'super_admin';
    SQL
  end
end
