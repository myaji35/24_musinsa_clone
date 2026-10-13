class CreateCharacters < ActiveRecord::Migration[7.2]
  def change
    create_table :characters do |t|
      t.string :name, null: false
      t.string :handle, null: false
      t.integer :age
      t.string :birthplace
      t.integer :age_band
      t.string :style_axis
      t.string :wardrobe
      t.text :personality
      t.string :status, default: "planned"
      t.timestamps
    end
    add_index :characters, :handle, unique: true
  end
end
