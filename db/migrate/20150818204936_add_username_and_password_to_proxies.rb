class AddUsernameAndPasswordToProxies < ActiveRecord::Migration
  def change
    add_column :proxies, :username, :string
    add_column :proxies, :password, :string
  end
end
