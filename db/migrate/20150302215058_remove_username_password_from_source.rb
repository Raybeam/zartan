class RemoveUsernamePasswordFromSource < ActiveRecord::Migration
  def change
    remove_column :sources, :username, :string
    remove_column :sources, :password, :string
  end
end
