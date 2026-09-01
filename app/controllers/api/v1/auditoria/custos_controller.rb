# frozen_string_literal: true

module Api
  module V1
    module Auditoria
      class CustosController < BaseController
        # GET /api/v1/auditoria/custos
        # Dashboard de auditoria financeira e métricas de consumo de IA
        def index
          scope = HistoricoExtracao.all

          if params[:provedor].present?
            scope = scope.where(nome_provedor: params[:provedor])
          end

          if params[:modelo].present?
            scope = scope.where(nome_modelo: params[:modelo])
          end

          if params[:data_inicio].present? && params[:data_fim].present?
            scope = scope.where(created_at: params[:data_inicio]..params[:data_fim])
          end

          resumo = {
            total_custo_usd: scope.sum(:custo_estimado_usd).to_f.round(6),
            total_tokens_entrada: scope.sum(:tokens_entrada),
            total_tokens_saida: scope.sum(:tokens_saida),
            total_tokens: scope.sum(:tokens_entrada) + scope.sum(:tokens_saida),
            total_processamentos: scope.count,
            tempo_medio_resposta_ms: (scope.average(:tempo_resposta_ms) || 0).to_f.round(1),
            gastos_por_provedor: scope.group(:nome_provedor).sum(:custo_estimado_usd).transform_values(&:to_f),
            gastos_por_modelo: scope.group(:nome_modelo).sum(:custo_estimado_usd).transform_values(&:to_f),
            processamentos_por_provedor: scope.group(:nome_provedor).count
          }

          ultimos_historicos = scope.order(created_at: :desc).limit(params[:limit] || 50)

          render json: {
            resumo: resumo,
            historicos: HistoricoExtracaoSerializer.new(ultimos_historicos).to_h
          }, status: :ok
        end
      end
    end
  end
end
