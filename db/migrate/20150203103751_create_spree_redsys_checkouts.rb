class CreateSpreeRedsysCheckouts < ActiveRecord::Migration
  def change
    create_table :spree_redsys_checkouts do |t|
      t.text :ds_params
      t.string :state
      t.timestamps
    end
  end
end
