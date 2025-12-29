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
  
  desc "Tự động tạo đăng ký ca mặc định cho tuần mới (chạy vào 00:01 Thứ 2 hàng tuần)"
  task auto_create_default: :environment do
    start_time = Time.current
    today = Date.current
    current_week_start = today.beginning_of_week(:monday)
    
    # Nếu hôm nay là Thứ 2 (wday = 1), tạo cho tuần này
    # Nếu không, tạo cho tuần tiếp theo
    if today.wday == 1 # Thứ 2
      week_start = current_week_start
    else
      week_start = current_week_start + 7.days
    end
    
    # Log header với timestamp
    log_header = "\n" + "=" * 80
    log_header += "\n🔄 CRON JOB: Tự động tạo đăng ký ca mặc định"
    log_header += "\n" + "=" * 80
    log_header += "\n⏰ Thời gian chạy: #{start_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    log_header += "\n📅 Ngày hiện tại: #{today} (#{today.strftime('%A')})"
    log_header += "\n📆 Tuần được tạo: #{week_start} → #{week_start + 6.days}"
    log_header += "\n" + "=" * 80
    puts log_header
    Rails.logger.info log_header
    
    # Tìm ca sáng và ca chiều
    all_shifts = WorkShift.all.index_by(&:id)
    morning_shift = all_shifts.values.find { |s| s.name.downcase.include?('sáng') || (s.start_time.present? && s.start_time < '12:00') }
    afternoon_shift = all_shifts.values.find { |s| s.name.downcase.include?('chiều') || (s.start_time.present? && s.start_time >= '12:00' && s.start_time < '18:00') }
    
    unless morning_shift || afternoon_shift
      puts "❌ Không tìm thấy ca sáng hoặc ca chiều. Vui lòng kiểm tra lại dữ liệu WorkShift."
      exit 1
    end
    
    shift_info = "📋 Ca sáng: #{morning_shift&.name || 'N/A'} (ID: #{morning_shift&.id})"
    shift_info += "\n📋 Ca chiều: #{afternoon_shift&.name || 'N/A'} (ID: #{afternoon_shift&.id})"
    puts shift_info
    Rails.logger.info shift_info
    
    # Lấy tất cả nhân viên active (không phải admin)
    staff_users = User.where(role: :staff, status: :active)
    total_staff = staff_users.count
    staff_info = "\n👥 Tổng số nhân viên: #{total_staff}"
    puts staff_info
    Rails.logger.info staff_info
    puts ""
    
    created_count = 0
    skipped_count = 0
    error_count = 0
    
    # Tạo 7 ngày trong tuần
    week_dates = (week_start..(week_start + 6.days)).to_a
    
    staff_users.find_each do |user|
      begin
        # Kiểm tra xem đã có đăng ký nào cho tuần này chưa (approved hoặc pending)
        existing_regs = ShiftRegistration.where(
          user_id: user.id,
          week_start: week_start,
          status: [:approved, :pending]
        )
        
        if existing_regs.any?
          skipped_count += 1
          skip_msg = "⏭️  #{user.full_name} (ID: #{user.id}): Đã có đăng ký (#{existing_regs.count} ca), bỏ qua"
          puts skip_msg
          Rails.logger.info skip_msg
          next
        end
        
        # Xác định các ca cần đăng ký dựa trên work_schedule_type
        shifts_to_register = []
        
        case user.work_schedule_type
        when 'both_shifts'
          # Cả ca sáng và ca chiều cho tất cả 7 ngày
          week_dates.each do |date|
            shifts_to_register << { date: date, shift: morning_shift } if morning_shift
            shifts_to_register << { date: date, shift: afternoon_shift } if afternoon_shift
          end
        when 'morning_only'
          # Chỉ ca sáng cho tất cả 7 ngày
          week_dates.each do |date|
            shifts_to_register << { date: date, shift: morning_shift } if morning_shift
          end
        when 'afternoon_only'
          # Chỉ ca chiều cho tất cả 7 ngày
          week_dates.each do |date|
            shifts_to_register << { date: date, shift: afternoon_shift } if afternoon_shift
          end
        else
          # Default: cả ca sáng và ca chiều
          week_dates.each do |date|
            shifts_to_register << { date: date, shift: morning_shift } if morning_shift
            shifts_to_register << { date: date, shift: afternoon_shift } if afternoon_shift
          end
        end
        
        # Tạo đăng ký với status approved (tự động duyệt)
        registrations_created = []
        shifts_to_register.each do |item|
          registration = ShiftRegistration.create!(
            user_id: user.id,
            work_shift_id: item[:shift].id,
            work_date: item[:date],
            week_start: week_start,
            status: :approved,
            note: 'Tự động tạo mặc định'
          )
          registrations_created << registration
        end
        
        created_count += registrations_created.count
        success_msg = "✅ #{user.full_name} (ID: #{user.id}): Đã tạo #{registrations_created.count} ca (#{user.work_schedule_type})"
        puts success_msg
        Rails.logger.info success_msg
        
      rescue => e
        error_count += 1
        error_msg = "❌ #{user.full_name} (ID: #{user.id}): Lỗi - #{e.message}"
        error_detail = "   #{e.backtrace.first(3).join("\n   ")}"
        puts error_msg
        puts error_detail
        Rails.logger.error error_msg
        Rails.logger.error error_detail
      end
    end
    
    end_time = Time.current
    duration = ((end_time - start_time) * 1000).round(2) # milliseconds
    
    # Summary log
    summary = "\n" + "=" * 80
    summary += "\n📊 KẾT QUẢ TỔNG KẾT:"
    summary += "\n" + "-" * 80
    summary += "\n   ✅ Đã tạo: #{created_count} ca"
    summary += "\n   ⏭️  Đã bỏ qua: #{skipped_count} nhân viên (đã có đăng ký)"
    summary += "\n   ❌ Lỗi: #{error_count} nhân viên"
    summary += "\n   👥 Tổng số nhân viên: #{total_staff}"
    summary += "\n   ⏱️  Thời gian xử lý: #{duration}ms"
    summary += "\n   📅 Tuần được tạo: #{week_start} → #{week_start + 6.days}"
    summary += "\n" + "-" * 80
    summary += "\n⏰ Kết thúc: #{end_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    summary += "\n" + "=" * 80
    summary += "\n✅ Hoàn thành!\n"
    
    puts summary
    Rails.logger.info summary
  end
end

