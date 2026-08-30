class CreateConfiguracoesIntegracoes < ActiveRecord::Migration[8.1]
  def change
    create_table :configuracoes_provedor_ia, id: :uuid do |t|
      t.string :nome_provedor, null: false
      t.string :nome_modelo, null: false
      t.text :credencial_criptografada
      t.boolean :ativo, default: false, null: false
      t.timestamps
    end
    add_index :configuracoes_provedor_ia, :nome_provedor

    create_table :configuracoes_whatsapp, id: :uuid do |t|
      t.string :nome, null: false
      t.string :tipo_provedor, null: false
      t.text :credencial_criptografada
      t.string :numero_telefone
      t.boolean :ativo, default: true, null: false
      t.timestamps
    end

    create_table :configuracoes_smtp, id: :uuid do |t|
      t.string :nome, null: false
      t.string :tipo_provedor, null: false
      t.text :credencial_criptografada
      t.string :endereco_email, null: false
      t.boolean :ativo, default: true, null: false
      t.timestamps
    end
  end
end
