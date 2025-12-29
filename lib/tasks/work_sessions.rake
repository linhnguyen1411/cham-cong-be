# lib/tasks/work_sessions.rake
namespace :work_sessions do
  desc "Process forgot checkouts - Run at 2:00 AM daily"
  task process_forgot_checkouts: :environment do
    puts "Processing forgot checkouts at #{Time.current}..."
    
    count = 0
    WorkSession.where(end_time: nil, forgot_checkout: false).find_each do |session|
      session.check_forgot_checkout!
      count += 1 if session.forgot_checkout?
    end
    
    puts "Marked #{count} sessions as forgot checkout."
  end
  
  desc "Check for sessions that should be marked as forgot checkout"
  task check_forgot: :environment do
    puts "Checking for forgot checkout sessions..."
    
    sessions = WorkSession.where(end_time: nil, forgot_checkout: false)
    puts "Found #{sessions.count} unclosed sessions:"
    
    sessions.each do |session|
      puts "  - Session ##{session.id}: User #{session.user&.full_name}, started at #{session.start_time}"
    end
  end

  desc "Fix long work sessions - Set end_time to nil if checkout time is after 02:00 next day (quên checkout)"
  task fix_long_sessions: :environment do
    start_time = Time.current
    puts "================================================================================"
    puts "🔧 FIX LONG WORK SESSIONS - Xử lý các ca làm việc quên checkout"
    puts "================================================================================"
    puts "⏰ Thời gian chạy: #{start_time.strftime('%Y-%m-%d %H:%M:%S %z')}"
    puts "================================================================================"
    
    timezone = 'Bangkok'
    fixed_count = 0
    checked_count = 0
    
    # Tìm tất cả các ca có end_time
    WorkSession.where.not(end_time: nil).find_each do |session|
      checked_count += 1
      
      start_time_tz = session.start_time.in_time_zone(timezone)
      end_time_tz = session.end_time.in_time_zone(timezone)
      session_date = start_time_tz.to_date
      
      # Tính thời gian 02:00 hôm sau
      next_day_2am = (session_date + 1.day).in_time_zone(timezone).change(hour: 2, min: 0)
      
      # Nếu end_time quá 02:00 hôm sau thì coi như quên checkout
      if end_time_tz > next_day_2am
        duration_hours = ((end_time_tz - start_time_tz) / 3600.0).round(2)
        
        puts "  🔍 Session ##{session.id}:"
        puts "     👤 User: #{session.user&.full_name || 'N/A'}"
        puts "     📅 Ngày: #{session_date.strftime('%Y-%m-%d')}"
        puts "     ⏰ Bắt đầu: #{start_time_tz.strftime('%H:%M:%S')}"
        puts "     ⏰ Kết thúc cũ: #{end_time_tz.strftime('%Y-%m-%d %H:%M:%S')} (#{duration_hours} giờ)"
        puts "     ❌ Quá 02:00 hôm sau -> Set end_time = nil (quên checkout, không tính vào ca hoàn thành)"
        
        # Set end_time = nil (coi như trống ca, không tính vào ca hoàn thành)
        session.update!(
          end_time: nil,
          duration_minutes: nil,
          forgot_checkout: true,
          is_early_checkout: false,
          minutes_before_end: 0
        )
        
        fixed_count += 1
        puts "     ✅ Đã fix: end_time = nil (quên checkout)"
      end
    end
    
    end_time = Time.current
    puts ""
    puts "================================================================================"
    puts "📊 KẾT QUẢ:"
    puts "--------------------------------------------------------------------------------"
    puts "   🔍 Đã kiểm tra: #{checked_count} ca"
    puts "   ✅ Đã fix: #{fixed_count} ca"
    puts "   ⏱️  Thời gian xử lý: #{((end_time - start_time) * 1000).round(2)}ms"
    puts "================================================================================"
    puts "✅ Hoàn thành!"
  end

  desc "Auto fix forgot checkouts for new day - Check and fix sessions when entering new day"
  task auto_fix_new_day: :environment do
    puts "Auto fixing forgot checkouts for new day at #{Time.current}..."
    WorkSession.auto_fix_forgot_checkouts_for_new_day!
  end
end

