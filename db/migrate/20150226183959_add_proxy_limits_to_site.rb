class AddProxyLimitsToSite < ActiveRecord::Migration
  def change
    add_column :sites, :min_proxies, :integer, :null => false, :default => 5
    add_column :sites, :max_proxies, :integer, :null => false, :default => 10
  end
end
