class CreateSources < ActiveRecord::Migration
  def change
    create_table :sources do |t|
      t.string :type, null: false
      t.string :name, null: false
      t.string :username
      t.string :password
      t.integer :max_proxies
      t.float :reliability, null: false, default: 50
      t.timestamp :deleted_at

      t.timestamps null: false
    end
    add_index :sources, :type, unique: true
    add_index :sources, :name, unique: true
    add_index :sources, :deleted_at
  end
end
