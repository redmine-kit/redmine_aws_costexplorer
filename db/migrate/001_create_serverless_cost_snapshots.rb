# frozen_string_literal: true

class CreateServerlessCostSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :serverless_cost_snapshots do |t|
      t.datetime :requested_at, null: false
      t.string :requested_by, null: false
      t.datetime :fetched_at
      t.text :data
      t.text :error
      t.integer :requests, null: false, default: 0
    end
    add_index :serverless_cost_snapshots, :requested_at
  end
end
