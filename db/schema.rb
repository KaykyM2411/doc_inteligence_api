# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_30_231734) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "cidades", force: :cascade do |t|
    t.bigint "estado_id", null: false
    t.string "nome", null: false
    t.index ["estado_id", "nome"], name: "index_cidades_on_estado_id_and_nome"
    t.index ["estado_id"], name: "index_cidades_on_estado_id"
  end

  create_table "clientes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cpf", limit: 14
    t.datetime "created_at", null: false
    t.string "email"
    t.string "nome", null: false
    t.string "telefone"
    t.datetime "updated_at", null: false
    t.index ["cpf"], name: "index_clientes_on_cpf", unique: true
  end

  create_table "configuracoes_provedor_ia", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "ativo", default: false, null: false
    t.datetime "created_at", null: false
    t.text "credencial_criptografada"
    t.string "nome_modelo", null: false
    t.string "nome_provedor", null: false
    t.datetime "updated_at", null: false
    t.index ["nome_provedor"], name: "index_configuracoes_provedor_ia_on_nome_provedor"
  end

  create_table "configuracoes_smtp", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "ativo", default: true, null: false
    t.datetime "created_at", null: false
    t.text "credencial_criptografada"
    t.string "endereco_email", null: false
    t.string "nome", null: false
    t.string "tipo_provedor", null: false
    t.datetime "updated_at", null: false
  end

  create_table "configuracoes_whatsapp", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "ativo", default: true, null: false
    t.datetime "created_at", null: false
    t.text "credencial_criptografada"
    t.string "nome", null: false
    t.string "numero_telefone"
    t.string "tipo_provedor", null: false
    t.datetime "updated_at", null: false
  end

  create_table "documentos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cliente_id"
    t.datetime "created_at", null: false
    t.jsonb "dados_extraidos", default: {}, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "nome_arquivo"
    t.string "origem", null: false
    t.string "referencia_origem"
    t.datetime "revisado_em"
    t.uuid "revisado_por_id"
    t.float "score_confianca", default: 0.0, null: false
    t.string "sha256_arquivo", limit: 64, null: false
    t.string "status", default: "pendente", null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.text "url_arquivo_bruto"
    t.integer "versao_schema", default: 1, null: false
    t.index ["cliente_id", "sha256_arquivo"], name: "idx_documentos_cliente_sha256", unique: true, where: "(cliente_id IS NOT NULL)"
    t.index ["cliente_id"], name: "index_documentos_on_cliente_id"
    t.index ["origem", "referencia_origem"], name: "idx_documentos_origem_referencia", unique: true, where: "(referencia_origem IS NOT NULL)"
    t.index ["revisado_por_id"], name: "index_documentos_on_revisado_por_id"
    t.index ["sha256_arquivo"], name: "idx_documentos_sha256_nulo", where: "(cliente_id IS NULL)"
    t.index ["status"], name: "index_documentos_on_status"
    t.index ["tipo"], name: "index_documentos_on_tipo"
  end

  create_table "enderecos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "bairro"
    t.string "cep", limit: 10
    t.bigint "cidade_id", null: false
    t.uuid "cliente_id", null: false
    t.string "complemento"
    t.datetime "created_at", null: false
    t.string "logradouro", null: false
    t.string "numero", null: false
    t.datetime "updated_at", null: false
    t.index ["cidade_id"], name: "index_enderecos_on_cidade_id"
    t.index ["cliente_id"], name: "index_enderecos_on_cliente_id"
  end

  create_table "estados", force: :cascade do |t|
    t.string "nome", null: false
    t.string "sigla", limit: 2, null: false
    t.index ["sigla"], name: "index_estados_on_sigla", unique: true
  end

  create_table "historicos_extracao", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "configuracao_provedor_ia_id"
    t.datetime "created_at", null: false
    t.decimal "custo_estimado_usd", precision: 10, scale: 6, default: "0.0", null: false
    t.uuid "documento_id", null: false
    t.text "mensagem_erro"
    t.string "nome_modelo", null: false
    t.string "nome_provedor", null: false
    t.jsonb "resposta_bruta"
    t.integer "tempo_resposta_ms", default: 0, null: false
    t.integer "tokens_entrada", default: 0, null: false
    t.integer "tokens_saida", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "versao_prompt", default: "v1.0", null: false
    t.index ["configuracao_provedor_ia_id"], name: "index_historicos_extracao_on_configuracao_provedor_ia_id"
    t.index ["documento_id"], name: "index_historicos_extracao_on_documento_id"
    t.index ["nome_modelo"], name: "index_historicos_extracao_on_nome_modelo"
    t.index ["nome_provedor"], name: "index_historicos_extracao_on_nome_provedor"
  end

  create_table "jwt_denylists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "notificacoes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "conteudo", null: false
    t.datetime "created_at", null: false
    t.datetime "lida_em"
    t.jsonb "metadados", default: {}, null: false
    t.string "titulo", null: false
    t.datetime "updated_at", null: false
    t.index ["lida_em"], name: "index_notificacoes_on_lida_em"
  end

  create_table "usuarios", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "nome", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_usuarios_on_email", unique: true
    t.index ["reset_password_token"], name: "index_usuarios_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cidades", "estados"
  add_foreign_key "documentos", "clientes"
  add_foreign_key "documentos", "usuarios", column: "revisado_por_id"
  add_foreign_key "enderecos", "cidades"
  add_foreign_key "enderecos", "clientes"
  add_foreign_key "historicos_extracao", "configuracoes_provedor_ia", column: "configuracao_provedor_ia_id"
  add_foreign_key "historicos_extracao", "documentos", on_delete: :cascade
end
