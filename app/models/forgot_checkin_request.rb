class ForgotCheckinRequest < ApplicationRecord
  include SoftDeletable
  
  belongs_to :user
  belongs_to :approved_by, class_name: 'User', optional: true

  validates :request_date, presence: true
  validates :request_type, presence: true, inclusion: { in: %w[checkin checkout] }
  validates :reason, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }
  validates :request_time, presence: true, format: { with: /\A([0-1][0-9]|2[0-3]):[0-5][0-9]\z/, message: 'phải có định dạng HH:mm' }
  
  validate :max_requests_per_month
  validate :request_date_not_future

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :this_month, -> { where(request_date: Date.current.beginning_of_month..Date.current.end_of_month) }

  def approve!(admin_user)
    transaction do
      update!(
        status: 'approved',
        approved_by: admin_user,
        approved_at: Time.current
      )
      
      # Tự động tạo WorkSession với giờ đã chọn
      create_work_session_from_request
    end
  end

  def create_work_session_from_request
    timezone = 'Bangkok'
    date = request_date.in_time_zone(timezone)
    time_parts = request_time.split(':')
    hour = time_parts[0].to_i
    minute = time_parts[1].to_i
    
    session_datetime = date.change(hour: hour, min: minute)
    
    if request_type == 'checkin'
      # Tạo WorkSession với start_time = request_time
      # Kiểm tra xem đã có session nào cho ngày này chưa
      existing_session = WorkSession.where(
        user_id: user_id,
        date: request_date
      ).first
      
      if existing_session
        # Nếu đã có session, cập nhật start_time
        existing_session.update!(
          start_time: session_datetime,
          forgot_checkout: false
        )
        # Recalculate duration nếu đã có end_time
        if existing_session.end_time.present?
          existing_session.update!(
            duration_minutes: ((existing_session.end_time - existing_session.start_time) / 60).to_i
          )
        end
      else
        # Tạo session mới
        WorkSession.create!(
          user_id: user_id,
          start_time: session_datetime,
          date: request_date,
          ip_address: nil # Không có IP vì là xin quên
        )
      end
    else # checkout
      # Tìm session của ngày đó và cập nhật end_time
      session = WorkSession.where(
        user_id: user_id,
        date: request_date
      ).first
      
      if session
        session.update!(
          end_time: session_datetime,
          forgot_checkout: false
        )
        # Recalculate duration - đảm bảo tính lại sau khi update
        session.reload
        if session.start_time.present? && session.end_time.present?
          duration_minutes = ((session.end_time - session.start_time) / 60).to_i
          session.update_column(:duration_minutes, duration_minutes)
        end
      else
        # Nếu không có session, tạo session mới với cả start và end
        # Giả sử start_time là 8:00 (có thể điều chỉnh)
        default_start = date.change(hour: 8, min: 0)
        duration_minutes = ((session_datetime - default_start) / 60).to_i
        WorkSession.create!(
          user_id: user_id,
          start_time: default_start,
          end_time: session_datetime,
          date: request_date,
          duration_minutes: duration_minutes,
          ip_address: nil
        )
      end
    end
  end

  def reject!(admin_user, reason = nil)
    update!(
      status: 'rejected',
      approved_by: admin_user,
      approved_at: Time.current,
      rejected_reason: reason
    )
  end

  private

  def max_requests_per_month
    return unless user_id && request_date

    current_month_requests = ForgotCheckinRequest
      .where(user_id: user_id)
      .where(request_date: request_date.beginning_of_month..request_date.end_of_month)
      .where.not(id: id) # Exclude current record when updating
    
    if current_month_requests.count >= 3
      errors.add(:base, 'Bạn đã đạt giới hạn 3 lần xin quên checkin/checkout trong tháng này')
    end
  end

  def request_date_not_future
    return unless request_date

    if request_date > Date.current
      errors.add(:request_date, 'Không thể xin quên checkin/checkout cho ngày tương lai')
    end
  end
end
