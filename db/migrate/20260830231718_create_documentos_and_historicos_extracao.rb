class CreateDocumentosAndHistoricosExtracao < ActiveRecord::Migration[8.1]
  def change
    create_table :documentos, id: :uuid do |t|
      t.references :cliente, null: true, foreign_key: { to_table: :clientes }, type: :uuid
      t.string :tipo, null: false
      t.string :origem, null: false
      t.string :referencia_origem
      t.string :status, null: false, default: "pendente"
      t.string :sha256_arquivo, limit: 64, null: false
      t.text :url_arquivo_bruto
      t.string :nome_arquivo
      t.jsonb :dados_extraidos, default: {}, null: false
      t.integer :versao_schema, default: 1, null: false
      t.float :score_confianca, default: 0.0, null: false
      t.integer :lock_version, default: 0, null: false
      t.references :revisado_por, null: true, foreign_key: { to_table: :usuarios }, type: :uuid
      t.datetime :revisado_em
      t.timestamps
    end

    add_index :documentos, [ :origem, :referencia_origem ],
              unique: true,
              where: "referencia_origem IS NOT NULL",
              name: "idx_documentos_origem_referencia"

    add_index :documentos, [ :cliente_id, :sha256_arquivo ],
              unique: true,
              where: "cliente_id IS NOT NULL",
              name: "idx_documentos_cliente_sha256"

    add_index :documentos, :sha256_arquivo,
              where: "cliente_id IS NULL",
              name: "idx_documentos_sha256_nulo"

    add_index :documentos, :status
    add_index :documentos, :tipo

    create_table :historicos_extracao, id: :uuid do |t|
      t.references :documento, null: false, foreign_key: { to_table: :documentos, on_delete: :cascade }, type: :uuid
      t.references :configuracao_provedor_ia, null: true, foreign_key: { to_table: :configuracoes_provedor_ia }, type: :uuid
      t.string :nome_provedor, null: false
      t.string :nome_modelo, null: false
      t.string :versao_prompt, null: false, default: "v1.0"
      t.integer :tokens_entrada, default: 0, null: false
      t.integer :tokens_saida, default: 0, null: false
      t.integer :tempo_resposta_ms, default: 0, null: false
      t.decimal :custo_estimado_usd, precision: 10, scale: 6, default: 0.0, null: false
      t.jsonb :resposta_bruta
      t.text :mensagem_erro
      t.timestamps
    end

    add_index :historicos_extracao, :nome_provedor
    add_index :historicos_extracao, :nome_modelo
  end
end
