class CreateProxies < ActiveRecord::Migration
  def change
    create_table :proxies do |t|
      t.string :host, null: false
      t.integer :port, null: false
      t.references :source, index: true, null: false
      t.timestamp :deleted_at

      t.timestamps null: false
    end
    add_index :proxies, [:host, :port], unique: true
    add_index :proxies, :deleted_at
    add_foreign_key :proxies, :sources
  end
end
