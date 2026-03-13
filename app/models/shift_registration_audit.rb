class ShiftRegistrationAudit < ApplicationRecord
  ACTIONS = %w[deleted].freeze

  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :target_user, class_name: 'User', optional: true
  belongs_to :shift_registration, optional: true
  belongs_to :work_shift, optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
end


