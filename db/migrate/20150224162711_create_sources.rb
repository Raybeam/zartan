class CreateSources < ActiveRecord::Migration
  def change
    create_table :sources do |t|
      t.string :type
      t.string :username
      t.string :password
      t.integer :max_proxies
      t.float :reliability
      t.timestamp :deleted_at

      t.timestamps null: false
    end
  end
end
