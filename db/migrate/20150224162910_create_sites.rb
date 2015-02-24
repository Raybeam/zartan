class CreateSites < ActiveRecord::Migration
  def change
    create_table :sites do |t|
      t.string :name, null: false
      t.timestamp :deleted_at

      t.timestamps null: false
    end
    add_index :sites, :name, unique: true
    add_index :sites, :deleted_at
  end
end
