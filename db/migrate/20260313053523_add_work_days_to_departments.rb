class AddWorkDaysToDepartments < ActiveRecord::Migration[7.0]
  def change
    # work_days: array of Ruby wday integers (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat)
    # Default Mon-Fri [1,2,3,4,5]
    add_column :departments, :work_days, :jsonb, default: [1, 2, 3, 4, 5]
  end
end
