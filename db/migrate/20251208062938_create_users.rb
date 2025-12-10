class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :username, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.string :full_name
      t.integer :role, default: 0
      t.string :avatar_url
      t.timestamps
    end
  end
end
