class FixUsernameUniqueIndexForSoftDelete < ActiveRecord::Migration[7.1]
  def up
    # Remove old unique index on username (nếu có)
    if index_exists?(:users, :username, unique: true)
      remove_index :users, :username
    end
    
    # Tạo partial unique index chỉ áp dụng cho records chưa bị soft delete
    # Điều này cho phép tạo user mới với username giống user đã bị xóa
    add_index :users, :username, 
              unique: true, 
              where: 'deleted_at IS NULL',
              name: 'index_users_on_username_unique_not_deleted'
  end
  
  def down
    # Rollback: remove partial index và tạo lại index thường
    if index_exists?(:users, :username, name: 'index_users_on_username_unique_not_deleted')
      remove_index :users, name: 'index_users_on_username_unique_not_deleted'
    end
    
    # Tạo lại unique index thường (nếu cần rollback)
    unless index_exists?(:users, :username, unique: true)
      add_index :users, :username, unique: true
    end
  end
end
