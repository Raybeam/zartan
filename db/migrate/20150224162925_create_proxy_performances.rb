class CreateProxyPerformances < ActiveRecord::Migration
  def change
    create_table :proxy_performances do |t|
      t.references :proxy, index: true
      t.references :site, index: true
      t.timestamp :reset_at
      t.timestamp :deleted_at

      t.timestamps null: false
    end
    add_foreign_key :proxy_performances, :proxies
    add_foreign_key :proxy_performances, :sites
  end
end
