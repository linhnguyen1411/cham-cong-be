namespace :roles do
  desc "Migrate existing users from enum role to role_id"
  task migrate_users: :environment do
    admin_role = Role.find_by(name: 'admin')
    staff_role = Role.find_by(name: 'staff')
    
    unless admin_role && staff_role
      puts "❌ Roles not found. Please run: rails db:seed"
      exit 1
    end
    
    migrated_count = 0
    
    # Migrate users with legacy admin role
    User.where(role: 0, role_id: nil).find_each do |user|
      user.update_column(:role_id, admin_role.id)
      migrated_count += 1
    end
    
    # Migrate users with legacy staff role
    User.where(role: 1, role_id: nil).find_each do |user|
      user.update_column(:role_id, staff_role.id)
      migrated_count += 1
    end
    
    puts "✅ Migrated #{migrated_count} users to role-based system"
  end
  
  desc "Create super admin user"
  task create_super_admin: :environment do
    super_admin_role = Role.find_by(name: 'super_admin')
    unless super_admin_role
      puts "❌ Super admin role not found. Please run: rails db:seed"
      exit 1
    end
    
    print "Username: "
    username = STDIN.gets.chomp
    print "Password: "
    password = STDIN.noecho(&:gets).chomp
    puts
    
    user = User.find_or_initialize_by(username: username)
    user.assign_attributes(
      password: password,
      password_confirmation: password,
      full_name: 'Super Admin',
      role_id: super_admin_role.id,
      status: :active
    )
    
    if user.save
      puts "✅ Super admin created: #{username}"
    else
      puts "❌ Error: #{user.errors.full_messages.join(', ')}"
    end
  end
end

