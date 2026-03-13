namespace :deploy do
  desc "Chay sau moi lan deploy: migrate DB, seed roles/permissions, dong bo role_id"
  task sync: :environment do
    puts "\n" + "=" * 60
    puts "DEPLOY SYNC - #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "=" * 60

    # -------------------------------------------------------
    # BUOC 1: Chay DB migrations
    # -------------------------------------------------------
    puts "\n[1/6] Chay DB migrations..."
    begin
      ActiveRecord::Migration.maintain_test_schema! rescue nil
      ActiveRecord::Base.connection.migration_context.migrate
      puts "     OK - schema phien ban: #{ActiveRecord::Base.connection.migration_context.current_version}"
    rescue => e
      puts "     LOI: #{e.message}"
      raise
    end

    # -------------------------------------------------------
    # BUOC 2: Doi ten role cu (neu ton tai) -> ten moi
    # admin            -> branch_admin
    # department_manager -> department_head
    # -------------------------------------------------------
    puts "\n[2/6] Doi ten roles cu sang ten moi..."
    begin
      renames = { 'admin' => 'branch_admin', 'department_manager' => 'department_head' }
      renames.each do |old_name, new_name|
        old_role = Role.find_by(name: old_name)
        new_role = Role.find_by(name: new_name)
        if old_role && new_role.nil?
          # Chi co role cu, chua co role moi -> doi ten
          old_role.update_columns(name: new_name)
          puts "     OK - Doi ten '#{old_name}' -> '#{new_name}'"
        elsif old_role && new_role
          # Ca hai ton tai: chuyen user tu role cu sang role moi, xoa role cu
          moved = User.unscoped.where(role_id: old_role.id).update_all(role_id: new_role.id)
          old_role.destroy
          puts "     OK - Merge '#{old_name}' -> '#{new_name}' (#{moved} users chuyen)"
        else
          puts "     SKIP - '#{old_name}' khong ton tai (da doi ten truoc do)"
        end
      end
    rescue => e
      puts "     LOI: #{e.message}"
    end

    # -------------------------------------------------------
    # BUOC 3: Seed roles & permissions (idempotent: find_or_create)
    # -------------------------------------------------------
    puts "\n[3/6] Seed roles va permissions..."
    begin
      Rake::Task['db:seed'].invoke
      puts "     OK - #{Role.count} roles, #{defined?(Permission) ? Permission.count : 0} permissions"
    rescue => e
      puts "     LOI: #{e.message}"
    end

    # -------------------------------------------------------
    # BUOC 4: Map role_id tu enum role cu (0 = admin -> branch_admin)
    # User co legacy role=0 va chua co role_id -> gan branch_admin
    # User co legacy role=1 va chua co role_id -> gan staff
    # -------------------------------------------------------
    puts "\n[4/6] Dong bo role_id tu legacy role enum..."
    begin
      branch_admin_role = Role.find_by(name: 'branch_admin')
      staff_role        = Role.find_by(name: 'staff')

      unless branch_admin_role && staff_role
        puts "     LOI: Khong tim thay roles. Hay chay db:seed truoc."
      else
        # Dung raw integer 0/1 vi enum prefix :legacy co the khac nhau theo version
        admin_migrated = User.unscoped
                             .where("users.role = 0 AND users.role_id IS NULL AND users.deleted_at IS NULL")
                             .update_all(role_id: branch_admin_role.id)
        staff_migrated = User.unscoped
                             .where("users.role = 1 AND users.role_id IS NULL AND users.deleted_at IS NULL")
                             .update_all(role_id: staff_role.id)
        puts "     OK - #{admin_migrated} branch_admin, #{staff_migrated} staff cap nhat"
      end
    rescue => e
      puts "     LOI: #{e.message}"
    end

    # -------------------------------------------------------
    # BUOC 5: Kiem tra va dam bao co it nhat 1 super_admin
    # -------------------------------------------------------
    puts "\n[5/6] Kiem tra super admin..."
    begin
      super_admin_role = Role.find_by(name: 'super_admin')
      if super_admin_role.nil?
        puts "     LOI: Khong co role super_admin. Chay db:seed truoc."
      else
        existing_super = User.unscoped.where(role_id: super_admin_role.id, deleted_at: nil).first
        if existing_super
          puts "     OK - Super admin: #{existing_super.username} (#{existing_super.full_name})"
        else
          # Promote user branch_admin dau tien thanh super_admin
          branch_admin_role = Role.find_by(name: 'branch_admin')
          first_admin = User.unscoped
                            .where(role_id: branch_admin_role&.id, deleted_at: nil)
                            .order(:id).first
          if first_admin
            first_admin.update_column(:role_id, super_admin_role.id)
            puts "     OK - Promote '#{first_admin.username}' thanh super_admin"
          else
            puts "     CANH BAO: Khong co admin nao de promote. Tao super admin thu cong:"
            puts "              rails roles:create_super_admin[username,password]"
          end
        end
      end
    rescue => e
      puts "     LOI: #{e.message}"
    end

    # -------------------------------------------------------
    # BUOC 6: Thiet lap gia tri mac dinh cho du lieu moi
    #   - work_days: cap nhat departments chua co work_days
    # -------------------------------------------------------
    puts "\n[6/6] Cap nhat gia tri mac dinh cho du lieu moi..."
    begin
      # Departments chua co work_days (null hoac []) -> gan mac dinh T2-T6 [1,2,3,4,5]
      if ActiveRecord::Base.connection.column_exists?(:departments, :work_days)
        updated = Department.unscoped
                            .where("work_days IS NULL OR work_days::text = '[]'")
                            .update_all(work_days: [1, 2, 3, 4, 5].to_json)
        puts "     OK - #{updated} departments duoc gan work_days mac dinh [T2-T6]"
      else
        puts "     SKIP - Cot work_days chua ton tai (migration chua chay?)"
      end
    rescue => e
      puts "     LOI: #{e.message}"
    end

    # -------------------------------------------------------
    # Tong ket
    # -------------------------------------------------------
    puts "\n" + "=" * 60
    puts "HOAN THANH"
    begin
      super_role        = Role.find_by(name: 'super_admin')
      branch_admin_role = Role.find_by(name: 'branch_admin')
      dept_head_role    = Role.find_by(name: 'department_head')
      pos_manager_role  = Role.find_by(name: 'position_manager')
      staff_role        = Role.find_by(name: 'staff')

      total  = User.unscoped.where(deleted_at: nil).count
      super_count  = User.unscoped.where(role_id: super_role&.id,        deleted_at: nil).count
      ba_count     = User.unscoped.where(role_id: branch_admin_role&.id, deleted_at: nil).count
      dh_count     = User.unscoped.where(role_id: dept_head_role&.id,    deleted_at: nil).count
      pm_count     = User.unscoped.where(role_id: pos_manager_role&.id,  deleted_at: nil).count
      staff_count  = User.unscoped.where(role_id: staff_role&.id,        deleted_at: nil).count
      null_count   = User.unscoped.where(role_id: nil,                   deleted_at: nil).count

      puts "  Tong users (active)  : #{total}"
      puts "  Super Admin          : #{super_count}"
      puts "  Branch Admin         : #{ba_count}"
      puts "  Quan ly khoi         : #{dh_count}"
      puts "  Quan ly vi tri       : #{pm_count}"
      puts "  Staff                : #{staff_count}"
      puts "  role_id = NULL       : #{null_count}#{null_count > 0 ? ' *** CAN KIEM TRA LAI ***' : ''}"
      puts "  Departments          : #{Department.unscoped.count} (#{Department.unscoped.where.not(work_days: nil).count} co work_days)"
      puts "  BranchManagers       : #{BranchManager.count}"
      puts "  DeptManagers         : #{DepartmentManager.count}"
      puts "  PosManagers          : #{PositionManager.count}"
    rescue => e
      # ignore summary errors
    end
    puts "=" * 60 + "\n"
  end
end
