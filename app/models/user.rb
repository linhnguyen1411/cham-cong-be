class User < ApplicationRecord
  has_secure_password
  has_one_attached :avatar
  
  validates :username, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, on: :create
  validates :password, length: { minimum: 6 }, allow_blank: true, on: :update
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
  
  def avatar_url
    if avatar.attached?
      # Use rails_blob_url which handles the redirect correctly
      Rails.application.routes.url_helpers.rails_blob_url(avatar, host: 'chamcong.minhtranholdings.vn', protocol: 'https')
    else
      read_attribute(:avatar_url) # fallback to DB column
    end
  rescue StandardError => e
    Rails.logger.error "Avatar URL error: #{e.message}"
    nil
  end
  
  def as_json(options = {})
    json = super(options.merge(except: :password_digest))
    json['avatar_url'] = avatar_url
    json
  end

end