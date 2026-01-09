# Seed Roles and Permissions

# Create Super Admin Role
super_admin_role = Role.find_or_create_by!(name: 'super_admin') do |role|
  role.description = 'Super Admin - Toàn quyền hệ thống'
  role.is_system = true
end

# Create Admin Role
admin_role = Role.find_or_create_by!(name: 'admin') do |role|
  role.description = 'Admin - Quản lý hệ thống'
  role.is_system = true
end

# Create Staff Role
staff_role = Role.find_or_create_by!(name: 'staff') do |role|
  role.description = 'Nhân viên - Quyền cơ bản'
  role.is_system = true
end

# Create Department Manager Role
dept_manager_role = Role.find_or_create_by!(name: 'department_manager') do |role|
  role.description = 'Trưởng bộ phận - Quản lý bộ phận'
  role.is_system = true
end

# Define all permissions
permissions_data = [
  # Users permissions
  { name: 'Xem danh sách người dùng', resource: 'users', action: 'index', description: 'Xem danh sách tất cả người dùng' },
  { name: 'Xem chi tiết người dùng', resource: 'users', action: 'show', description: 'Xem thông tin chi tiết người dùng' },
  { name: 'Tạo người dùng', resource: 'users', action: 'create', description: 'Tạo người dùng mới' },
  { name: 'Sửa người dùng', resource: 'users', action: 'update', description: 'Cập nhật thông tin người dùng' },
  { name: 'Xóa người dùng', resource: 'users', action: 'delete', description: 'Xóa người dùng' },
  
  # Work Sessions permissions
  { name: 'Xem lịch sử làm việc', resource: 'work_sessions', action: 'index', description: 'Xem lịch sử chấm công' },
  { name: 'Xem chi tiết ca làm việc', resource: 'work_sessions', action: 'show', description: 'Xem chi tiết ca làm việc' },
  { name: 'Tạo ca làm việc', resource: 'work_sessions', action: 'create', description: 'Check-in/Check-out' },
  { name: 'Sửa ca làm việc', resource: 'work_sessions', action: 'update', description: 'Cập nhật ca làm việc' },
  { name: 'Xóa ca làm việc', resource: 'work_sessions', action: 'delete', description: 'Xóa ca làm việc' },
  
  # Shift Registrations permissions
  { name: 'Xem đăng ký ca', resource: 'shift_registrations', action: 'index', description: 'Xem danh sách đăng ký ca' },
  { name: 'Xem chi tiết đăng ký ca', resource: 'shift_registrations', action: 'show', description: 'Xem chi tiết đăng ký ca' },
  { name: 'Tạo đăng ký ca', resource: 'shift_registrations', action: 'create', description: 'Đăng ký ca làm việc' },
  { name: 'Sửa đăng ký ca', resource: 'shift_registrations', action: 'update', description: 'Cập nhật đăng ký ca' },
  { name: 'Xóa đăng ký ca', resource: 'shift_registrations', action: 'delete', description: 'Xóa đăng ký ca' },
  { name: 'Duyệt đăng ký ca', resource: 'shift_registrations', action: 'approve', description: 'Duyệt đăng ký ca' },
  { name: 'Từ chối đăng ký ca', resource: 'shift_registrations', action: 'reject', description: 'Từ chối đăng ký ca' },
  
  # Work Shifts permissions
  { name: 'Xem ca làm việc', resource: 'work_shifts', action: 'index', description: 'Xem danh sách ca làm việc' },
  { name: 'Xem chi tiết ca làm việc', resource: 'work_shifts', action: 'show', description: 'Xem chi tiết ca làm việc' },
  { name: 'Tạo ca làm việc', resource: 'work_shifts', action: 'create', description: 'Tạo ca làm việc mới' },
  { name: 'Sửa ca làm việc', resource: 'work_shifts', action: 'update', description: 'Cập nhật ca làm việc' },
  { name: 'Xóa ca làm việc', resource: 'work_shifts', action: 'delete', description: 'Xóa ca làm việc' },
  
  # Departments permissions
  { name: 'Xem khối/phòng ban', resource: 'departments', action: 'index', description: 'Xem danh sách khối/phòng ban' },
  { name: 'Xem chi tiết khối/phòng ban', resource: 'departments', action: 'show', description: 'Xem chi tiết khối/phòng ban' },
  { name: 'Tạo khối/phòng ban', resource: 'departments', action: 'create', description: 'Tạo khối/phòng ban mới' },
  { name: 'Sửa khối/phòng ban', resource: 'departments', action: 'update', description: 'Cập nhật khối/phòng ban' },
  { name: 'Xóa khối/phòng ban', resource: 'departments', action: 'delete', description: 'Xóa khối/phòng ban' },
  
  # Branches permissions
  { name: 'Xem chi nhánh', resource: 'branches', action: 'index', description: 'Xem danh sách chi nhánh' },
  { name: 'Xem chi tiết chi nhánh', resource: 'branches', action: 'show', description: 'Xem chi tiết chi nhánh' },
  { name: 'Tạo chi nhánh', resource: 'branches', action: 'create', description: 'Tạo chi nhánh mới' },
  { name: 'Sửa chi nhánh', resource: 'branches', action: 'update', description: 'Cập nhật chi nhánh' },
  { name: 'Xóa chi nhánh', resource: 'branches', action: 'delete', description: 'Xóa chi nhánh' },
  
  # Positions permissions
  { name: 'Xem vị trí', resource: 'positions', action: 'index', description: 'Xem danh sách vị trí' },
  { name: 'Xem chi tiết vị trí', resource: 'positions', action: 'show', description: 'Xem chi tiết vị trí' },
  { name: 'Tạo vị trí', resource: 'positions', action: 'create', description: 'Tạo vị trí mới' },
  { name: 'Sửa vị trí', resource: 'positions', action: 'update', description: 'Cập nhật vị trí' },
  { name: 'Xóa vị trí', resource: 'positions', action: 'delete', description: 'Xóa vị trí' },
  
  # Forgot Checkin Requests permissions
  { name: 'Xem yêu cầu quên checkin/out', resource: 'forgot_checkin_requests', action: 'index', description: 'Xem danh sách yêu cầu quên checkin/out' },
  { name: 'Tạo yêu cầu quên checkin/out', resource: 'forgot_checkin_requests', action: 'create', description: 'Tạo yêu cầu quên checkin/out' },
  { name: 'Duyệt yêu cầu quên checkin/out', resource: 'forgot_checkin_requests', action: 'approve', description: 'Duyệt yêu cầu quên checkin/out' },
  { name: 'Từ chối yêu cầu quên checkin/out', resource: 'forgot_checkin_requests', action: 'reject', description: 'Từ chối yêu cầu quên checkin/out' },
  
  # Roles permissions
  { name: 'Xem vai trò', resource: 'roles', action: 'index', description: 'Xem danh sách vai trò' },
  { name: 'Xem chi tiết vai trò', resource: 'roles', action: 'show', description: 'Xem chi tiết vai trò' },
  { name: 'Tạo vai trò', resource: 'roles', action: 'create', description: 'Tạo vai trò mới' },
  { name: 'Sửa vai trò', resource: 'roles', action: 'update', description: 'Cập nhật vai trò' },
  { name: 'Xóa vai trò', resource: 'roles', action: 'delete', description: 'Xóa vai trò' },
  
  # Settings permissions
  { name: 'Xem cài đặt', resource: 'settings', action: 'show', description: 'Xem cài đặt hệ thống' },
  { name: 'Sửa cài đặt', resource: 'settings', action: 'update', description: 'Cập nhật cài đặt hệ thống' }
]

# Create permissions
permissions_data.each do |perm_data|
  Permission.find_or_create_by!(resource: perm_data[:resource], action: perm_data[:action]) do |p|
    p.name = perm_data[:name]
    p.description = perm_data[:description]
  end
end

# Assign all permissions to super_admin
super_admin_role.permissions = Permission.all

# Assign basic permissions to admin
admin_permissions = Permission.where(resource: ['users', 'work_sessions', 'shift_registrations', 'work_shifts', 'departments', 'branches', 'positions', 'forgot_checkin_requests', 'settings'])
admin_role.permissions = admin_permissions

# Assign basic permissions to staff
staff_permissions = Permission.where(resource: ['work_sessions', 'shift_registrations']).where(action: ['index', 'show', 'create'])
staff_role.permissions = staff_permissions

# Assign department management permissions to department_manager
dept_manager_permissions = Permission.where(resource: ['users', 'work_sessions', 'shift_registrations']).where(
  resource: 'users', action: ['index', 'show', 'create']
).or(
  Permission.where(resource: ['work_sessions', 'shift_registrations'], action: ['index', 'show'])
)
dept_manager_role.permissions = dept_manager_permissions

puts "✅ Seeded #{Role.count} roles and #{Permission.count} permissions"
