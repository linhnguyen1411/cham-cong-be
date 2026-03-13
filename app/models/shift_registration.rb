# app/models/shift_registration.rb
class ShiftRegistration < ApplicationRecord
  include SoftDeletable
  
  belongs_to :user
  belongs_to :work_shift
  belongs_to :approved_by, class_name: 'User', optional: true
  has_one :work_session
  
  validates :work_date, presence: true
  validates :week_start, presence: true
  # Cho phép nhiều ca trong 1 ngày, nhưng không được trùng ca
  # Chỉ validate uniqueness khi status là pending hoặc approved (cho phép đăng ký lại sau khi bị từ chối)
  validates :user_id, uniqueness: { 
    scope: [:work_date, :work_shift_id], 
    message: "đã đăng ký ca này cho ngày này",
    conditions: -> { where.not(status: :rejected) }
  }
  
  # Cho phép đăng ký cho tuần hiện tại (ngày tương lai) và tuần tới
  # Cho phép đăng ký từ thứ 6 tuần này cho tuần tới
  validate :registration_timing, on: :create
  
  enum status: { 
    pending: 0, 
    approved: 1, 
    rejected: 2 
  }
  
  before_validation :set_week_start, on: :create
  
  scope :for_week, ->(week_start) { where(week_start: week_start) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_date, ->(date) { where(work_date: date) }
  scope :pending_approval, -> { where(status: :pending) }
  scope :approved_only, -> { where(status: :approved) }

  # Soft delete with audit log (to track who removed registrations)
  def audit_soft_delete!(actor:, source: nil, reason: nil, metadata: {})
    ShiftRegistrationAudit.create!(
      action: 'deleted',
      actor_id: actor&.id,
      target_user_id: user_id,
      shift_registration_id: id,
      work_shift_id: work_shift_id,
      work_date: work_date,
      week_start: week_start,
      previous_status: status,
      source: source,
      reason: reason,
      metadata: metadata || {}
    )

    soft_delete!
  end

  # Soft delete as an "OFF" action (enforces off limits + capacity limits)
  # Use this for user/admin deleting a shift to take time off.
  def audit_soft_delete_for_off!(actor:, source: nil, reason: nil, metadata: {})
    self.class.ensure_off_deletion_allowed!(
      user: user,
      work_date: work_date,
      work_shift_id: work_shift_id
    )

    audit_soft_delete!(actor: actor, source: source, reason: reason, metadata: metadata)
  end
  
  def approve!(admin_user, note = nil)
    update!(
      status: :approved,
      approved_by: admin_user,
      approved_at: Time.current,
      admin_note: note
    )
  end
  
  def reject!(admin_user, note = nil)
    update!(
      status: :rejected,
      approved_by: admin_user,
      approved_at: Time.current,
      admin_note: note
    )
  end
  
  def shift_time_range
    return nil unless work_shift
    {
      start: "#{work_date} #{work_shift.start_time}",
      end: "#{work_date} #{work_shift.end_time}"
    }
  end
  
  def as_json(options = {})
    super(options).merge(
      'user_name' => user&.full_name,
      'shift_name' => work_shift&.name,
      'shift_start_time' => work_shift&.start_time,
      'shift_end_time' => work_shift&.end_time,
      'approved_by_name' => approved_by&.full_name,
      'status_text' => status_text
    )
  end
  
  def status_text
    case status
    when 'pending' then 'Chờ duyệt'
    when 'approved' then 'Đã duyệt'
    when 'rejected' then 'Từ chối'
    end
  end
  
  private

  def self.morning_shift_id
    WorkShift.all.find { |s| s.name.to_s.downcase.include?('sáng') || (s.start_time.present? && s.start_time < '12:00') }&.id
  end

  def self.afternoon_shift_id
    WorkShift.all.find { |s| s.name.to_s.downcase.include?('chiều') || (s.start_time.present? && s.start_time >= '12:00' && s.start_time < '18:00') }&.id
  end

  def self.required_shift_ids_for(user)
    ms = morning_shift_id
    as = afternoon_shift_id
    case user.work_schedule_type
    when 'both_shifts'
      [ms, as].compact
    when 'morning_only'
      ms ? [ms] : []
    when 'afternoon_only'
      as ? [as] : []
    else
      [ms, as].compact
    end
  end

  def self.shift_required_for_user?(user, work_shift_id)
    required_shift_ids_for(user).include?(work_shift_id.to_i)
  end

  def self.ensure_off_deletion_allowed!(user:, work_date:, work_shift_id:)
    return unless user && work_date && work_shift_id

    # Only enforce off rules for required shifts; overtime/non-required deletions are allowed.
    return unless shift_required_for_user?(user, work_shift_id)

    setting = AppSetting.current
    week_start = work_date.beginning_of_week(:monday)
    required_shift_ids = required_shift_ids_for(user)

    # 1) User weekly off limit
    week_dates_count = 7
    expected_required = week_dates_count * required_shift_ids.size

    current_required_count = ShiftRegistration
      .where(user_id: user.id, week_start: week_start, status: [:approved, :pending], work_shift_id: required_shift_ids)
      .count

    # Deleting a required registration will reduce the count by 1
    after_required_count = [current_required_count - 1, 0].max
    off_required_count_after = expected_required - after_required_count

    if user.work_schedule_type == 'both_shifts'
      max_off = setting.max_user_off_shifts_per_week
      if off_required_count_after > max_off
        raise StandardError, "Bạn chỉ được off tối đa #{max_off} ca/tuần. Hiện tại thao tác này sẽ làm bạn off #{off_required_count_after} ca."
      end
    else
      max_off_days = setting.max_user_off_days_per_week
      # For 1-shift schedules, missing required regs equals off days
      if off_required_count_after > max_off_days
        raise StandardError, "Bạn chỉ được off tối đa #{max_off_days} ngày/tuần. Hiện tại thao tác này sẽ làm bạn off #{off_required_count_after} ngày."
      end
    end

    # 2) Per-position per-shift per-day off capacity
    # Determine cohort: users that are required to work this shift and share the same position (or both nil).
    cohort_schedule_types =
      if work_shift_id.to_i == morning_shift_id
        %w[both_shifts morning_only]
      elsif work_shift_id.to_i == afternoon_shift_id
        %w[both_shifts afternoon_only]
      else
        # Unknown shift type -> don't enforce shift capacity
        nil
      end

    return unless cohort_schedule_types

    cohort = User.active_users.where(work_schedule_type: cohort_schedule_types)
    if user.position_id.present?
      cohort = cohort.where(position_id: user.position_id)
    else
      cohort = cohort.where(position_id: nil)
    end

    total_user_ids = cohort.pluck(:id)
    return if total_user_ids.empty?

    registered_count = ShiftRegistration
      .where(work_date: work_date, work_shift_id: work_shift_id, status: [:approved, :pending], user_id: total_user_ids)
      .distinct
      .count(:user_id)

    off_count_current = total_user_ids.size - registered_count
    max_shift_off = setting.max_shift_off_count_per_day

    # If already at limit, deleting another registration would exceed limit.
    if off_count_current >= max_shift_off
      shift_name = WorkShift.find_by(id: work_shift_id)&.name || "ca"
      raise StandardError, "#{shift_name} ngày #{work_date.strftime('%d/%m/%Y')} đã đủ số người off (#{max_shift_off} người/ca/vị trí)."
    end
  end
  
  def set_week_start
    return unless work_date
    # week_start = ngày thứ 2 của tuần chứa work_date
    self.week_start = work_date.beginning_of_week(:monday)
  end
  
  def registration_timing
    return unless work_date
    
    today = Date.current
    current_week_start = today.beginning_of_week(:monday)
    current_week_end = today.end_of_week(:sunday)
    next_week_start = today.next_week(:monday)
    next_week_end = next_week_start + 6.days
    
    # Cho phép đăng ký từ thứ 6 tuần này (current_week_start + 4 days) đến hết Chủ nhật cho tuần tới
    registration_window_start = current_week_start + 4.days # Thứ 6
    day_of_week = today.wday # 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    is_friday = day_of_week == 5 # Thứ 6
    
    # KHÔNG cho phép đăng ký cho tuần đã qua
    work_week_start = work_date.beginning_of_week(:monday)
    if work_week_start < current_week_start
      errors.add(:work_date, "Không thể đăng ký cho tuần đã qua")
      return
    end
    
    # Không cho đăng ký cho quá khứ (ngày đã qua)
    if work_date < today
      errors.add(:work_date, "Không thể đăng ký cho ngày đã qua")
      return
    end
    
    # Nếu đang ở trong tuần hiện tại và đăng ký cho ngày trong tương lai của tuần hiện tại - cho phép
    if work_date > today && work_date <= current_week_end && work_week_start == current_week_start
      return # OK - đăng ký cho ngày còn lại trong tuần này
    end
    
    # Nếu đăng ký cho tuần tới
    if work_date >= next_week_start && work_date <= next_week_end && work_week_start == next_week_start
      # Cho phép từ thứ 6 trở đi (bao gồm cả thứ 6)
      if today >= registration_window_start || is_friday
        return # OK - đang từ thứ 6 trở đi và đăng ký cho tuần tới
      else
        errors.add(:work_date, "Chỉ được đăng ký ca cho tuần tới từ thứ 6")
        return
      end
    end
    
    # Không cho đăng ký quá xa (sau tuần tới)
    if work_date > next_week_end
      errors.add(:work_date, "Chỉ được đăng ký cho tuần tới")
    end
  end
end

