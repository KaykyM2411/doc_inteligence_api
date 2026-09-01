# frozen_string_literal: true

class DocumentoSerializer < ApplicationSerializer
  attributes :id, :tipo, :origem, :referencia_origem, :sha256_arquivo,
             :status, :score_confianca, :nome_arquivo, :dados_extraidos,
             :versao_schema, :lock_version, :revisado_em, :created_at, :updated_at

  one :cliente, resource: ClienteResumoSerializer
  one :revisado_por, resource: UsuarioResumoSerializer
  many :historicos_extracao, resource: HistoricoExtracaoSerializer
end
