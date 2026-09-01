# frozen_string_literal: true

class HistoricoExtracaoSerializer < ApplicationSerializer
  attributes :id, :nome_provedor, :nome_modelo, :versao_prompt,
             :tokens_entrada, :tokens_saida, :tempo_resposta_ms,
             :custo_estimado_usd, :mensagem_erro, :created_at
end
