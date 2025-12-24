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
end

