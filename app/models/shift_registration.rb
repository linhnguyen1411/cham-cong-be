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
  
  # Chỉ cho phép đăng ký cho tuần tới (cuối tuần hiện tại)
  # TẠM THỜI BỎ CHECK ĐỂ TEST - SẼ BẬT LẠI SAU
  # validate :registration_timing, on: :create
  
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
      # Chỉ cho phép từ thứ 6 trở đi (tức là từ thứ 6 tuần này)
      if today < registration_window_start
        errors.add(:work_date, "Chỉ được đăng ký ca cho tuần tới từ thứ 6")
        return
      end
      # OK - đang từ thứ 6 trở đi và đăng ký cho tuần tới
      return
    end
    
    # Không cho đăng ký quá xa (sau tuần tới)
    if work_date > next_week_end
      errors.add(:work_date, "Chỉ được đăng ký cho tuần tới")
    end
  end
end

