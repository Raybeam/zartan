class AddUniqueIndexToSourcesType < ActiveRecord::Migration
  def change
    add_index :sources, :type, unique: true
  end
end
