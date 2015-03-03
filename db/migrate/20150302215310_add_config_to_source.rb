class AddConfigToSource < ActiveRecord::Migration
  def change
    add_column :sources, :config, :text
  end
end
