# db/migrate/20251220100002_add_position_to_users.rb
class AddPositionToUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :position, foreign_key: true
  end
end

