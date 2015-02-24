class RemoveUniqueIndexesFromSource < ActiveRecord::Migration
  def up
    remove_index :sources, :name
    remove_index :sources, :type
  end
  def down
    add_index :sources, :type, unique: true
    add_index :sources, :name, unique: true
  end
end
