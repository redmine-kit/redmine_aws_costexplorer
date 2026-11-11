# frozen_string_literal: true

class CreateAwsCostexplorerSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :aws_costexplorer_snapshots do |t|
      t.datetime :requested_at, null: false
      t.datetime :fetched_at
      t.text :data
      t.text :error
      t.integer :requests, null: false, default: 0
    end
    add_index :aws_costexplorer_snapshots, :requested_at
  end
end
