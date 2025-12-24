# lib/tasks/shift_registrations.rake
namespace :shift_registrations do
  desc "Xóa tất cả lịch sử đăng ký ca"
  task clear_all: :environment do
    count = ShiftRegistration.count
    puts "⚠️  Cảnh báo: Bạn sắp xóa #{count} đăng ký ca!"
    puts "Nhấn Ctrl+C để hủy, hoặc đợi 3 giây để tiếp tục..."
    
    sleep(3)
    
    deleted_count = ShiftRegistration.count
    ShiftRegistration.destroy_all
    
    puts "✅ Đã xóa #{deleted_count} đăng ký ca thành công!"
  end
  
  desc "Xóa đăng ký ca theo status (pending/approved/rejected)"
  task :clear_by_status, [:status] => :environment do |t, args|
    status = args[:status]&.to_sym
    unless status && ShiftRegistration.statuses.key?(status)
      puts "❌ Status không hợp lệ. Sử dụng: pending, approved, hoặc rejected"
      exit 1
    end
    
    count = ShiftRegistration.where(status: status).count
    puts "⚠️  Bạn sắp xóa #{count} đăng ký ca với status: #{status}"
    puts "Nhấn Ctrl+C để hủy, hoặc đợi 3 giây để tiếp tục..."
    
    sleep(3)
    
    deleted_count = ShiftRegistration.where(status: status).count
    ShiftRegistration.where(status: status).destroy_all
    
    puts "✅ Đã xóa #{deleted_count} đăng ký ca với status: #{status}!"
  end
  
  desc "Xóa đăng ký ca cũ (trước ngày chỉ định)"
  task :clear_old, [:date] => :environment do |t, args|
    date_str = args[:date]
    unless date_str
      puts "❌ Vui lòng cung cấp ngày (YYYY-MM-DD)"
      puts "Ví dụ: rake shift_registrations:clear_old[2025-12-20]"
      exit 1
    end
    
    begin
      cutoff_date = Date.parse(date_str)
    rescue
      puts "❌ Ngày không hợp lệ. Sử dụng format: YYYY-MM-DD"
      exit 1
    end
    
    count = ShiftRegistration.where("work_date < ?", cutoff_date).count
    puts "⚠️  Bạn sắp xóa #{count} đăng ký ca trước ngày #{cutoff_date}"
    puts "Nhấn Ctrl+C để hủy, hoặc đợi 3 giây để tiếp tục..."
    
    sleep(3)
    
    deleted_count = ShiftRegistration.where("work_date < ?", cutoff_date).count
    ShiftRegistration.where("work_date < ?", cutoff_date).destroy_all
    
    puts "✅ Đã xóa #{deleted_count} đăng ký ca trước ngày #{cutoff_date}!"
  end
  
  desc "Hiển thị thống kê đăng ký ca"
  task stats: :environment do
    total = ShiftRegistration.count
    pending = ShiftRegistration.pending.count
    approved = ShiftRegistration.approved.count
    rejected = ShiftRegistration.rejected.count
    
    puts "\n📊 Thống kê đăng ký ca:"
    puts "=" * 40
    puts "Tổng số:        #{total}"
    puts "Chờ duyệt:      #{pending}"
    puts "Đã duyệt:       #{approved}"
    puts "Từ chối:        #{rejected}"
    puts "=" * 40
    
    if total > 0
      oldest = ShiftRegistration.order(:work_date).first
      newest = ShiftRegistration.order(work_date: :desc).first
      puts "\n📅 Phạm vi ngày:"
      puts "   Từ: #{oldest.work_date} (#{oldest.user&.full_name || 'N/A'})"
      puts "   Đến: #{newest.work_date} (#{newest.user&.full_name || 'N/A'})"
    end
  end
end

