class AddIpAddressToDepartments < ActiveRecord::Migration[7.1]
  def change
    add_column :departments, :ip_address, :string
  end
end
