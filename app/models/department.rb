class Department < ApplicationRecord
  include SoftDeletable
  
  has_many :users, dependent: :nullify
  has_many :work_shifts, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  # ip_address: string - IP cho phép checkin của khối
  # Ví dụ: "129.231.1.115"
end
