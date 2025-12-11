class Department < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :work_shifts, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  # Seed data examples:
  # Khối văn phòng, Khối công trình, Khối nhà hàng, Khối khách sạn
end
