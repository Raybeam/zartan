class CreateProxies < ActiveRecord::Migration
  def change
    create_table :proxies do |t|
      t.string :host
      t.integer :port
      t.references :source, index: true
      t.timestamp :deleted_at

      t.timestamps null: false
    end
    add_foreign_key :proxies, :sources
  end
end
