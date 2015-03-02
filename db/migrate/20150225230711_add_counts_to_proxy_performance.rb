class AddCountsToProxyPerformance < ActiveRecord::Migration
  def change
    add_column :proxy_performances, :times_succeeded, :integer,
      :null => false, :default => 0
    add_column :proxy_performances, :times_failed, :integer,
      :null => false, :default => 0
  end
end
