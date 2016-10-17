class CreateMessage < ActiveRecord::Migration
  def change
    create_table :messages do |m|
      m.string :token
      m.string :message
      m.string :destroy_type
      m.integer :visits_to_destroy
      m.datetime :time_to_destroy

    end
    add_index :messages, :token, unique: true
  end
end