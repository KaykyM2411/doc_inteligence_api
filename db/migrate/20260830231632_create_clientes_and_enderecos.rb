class CreateClientesAndEnderecos < ActiveRecord::Migration[8.1]
  def change
    create_table :clientes, id: :uuid do |t|
      t.string :nome, null: false
      t.string :cpf, limit: 14
      t.string :email
      t.string :telefone
      t.timestamps
    end
    add_index :clientes, :cpf, unique: true

    create_table :enderecos, id: :uuid do |t|
      t.references :cliente, null: false, foreign_key: { to_table: :clientes }, type: :uuid
      t.references :cidade, null: false, foreign_key: { to_table: :cidades }, type: :bigint
      t.string :logradouro, null: false
      t.string :numero, null: false
      t.string :bairro
      t.string :cep, limit: 10
      t.string :complemento
      t.timestamps
    end
  end
end
