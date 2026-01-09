class Branch < ApplicationRecord
  include SoftDeletable
  
  has_many :users, dependent: :nullify
  has_many :work_shifts, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :address, presence: true
end
