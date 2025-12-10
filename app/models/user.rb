class User < ApplicationRecord
  has_secure_password
  validates :username, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }
  validates :full_name, presence: true
  enum role: { admin: 0, staff: 1 }

  has_many :work_sessions, dependent: :destroy

  scope :staff, -> { where(role: :staff) }
  scope :admin, -> { where(role: :admin) }
  scope :most_active, -> { joins(:work_sessions).group(:id).order('COUNT(work_sessions.id) DESC') }

  def total_work_sessions
    work_sessions.count
  end

  def total_work_minutes
    work_sessions.sum(:duration_minutes)
  end
  
  def as_json(options = {})
    super(options.merge(except: :password_digest))
  end

end