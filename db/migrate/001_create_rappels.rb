class CreateRappels < ActiveRecord::Migration[5.2]
  def change
    create_table :rappels do |t|
      t.string :subject
      t.text :message
      t.integer :project_id
      t.integer :issue_id
      t.string :frequency_unit
      t.integer :frequency_value
      t.datetime :next_run_date
      t.datetime :last_run_date
      t.timestamps
    end
    
    add_index :rappels, :project_id
    add_index :rappels, :issue_id
  end
end 