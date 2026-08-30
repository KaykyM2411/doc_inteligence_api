class CreateNotificacoes < ActiveRecord::Migration[8.1]
  def change
    create_table :notificacoes, id: :uuid do |t|
      t.string :titulo, null: false
      t.text :conteudo, null: false
      t.datetime :lida_em
      t.jsonb :metadados, default: {}, null: false
      t.timestamps
    end
    add_index :notificacoes, :lida_em
  end
end
