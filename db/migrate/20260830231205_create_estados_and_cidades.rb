class CreateEstadosAndCidades < ActiveRecord::Migration[8.1]
  def change
    create_table :estados, id: :bigserial do |t|
      t.string :nome, null: false
      t.string :sigla, limit: 2, null: false
    end
    add_index :estados, :sigla, unique: true

    create_table :cidades, id: :bigserial do |t|
      t.references :estado, null: false, foreign_key: { to_table: :estados }, type: :bigint
      t.string :nome, null: false
    end
    add_index :cidades, [ :estado_id, :nome ]
  end
end
