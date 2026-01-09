module SoftDeletable
  extend ActiveSupport::Concern

  included do
    default_scope { where(deleted_at: nil) }
    
    scope :not_deleted, -> { where(deleted_at: nil) }
    scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
    scope :with_deleted, -> { unscoped }
  end

  def soft_delete!
    update_column(:deleted_at, Time.current)
  end

  def restore!
    update_column(:deleted_at, nil)
  end

  def deleted?
    deleted_at.present?
  end

  def destroy
    run_callbacks(:destroy) do
      soft_delete!
    end
  end

  def destroy!
    raise ActiveRecord::RecordNotDestroyed.new("Cannot destroy already deleted record", self) if deleted?
    soft_delete!
  end
end

