# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::MimeResponds

      before_action :authenticate_usuario!

      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :handle_unprocessable_entity
      rescue_from ActiveRecord::StaleObjectError, with: :handle_conflict

      protected

      def current_user
        current_usuario
      end

      private

      def handle_not_found(exception)
        render json: {
          error: "Recurso não encontrado",
          message: exception.message
        }, status: :not_found
      end

      def handle_unprocessable_entity(exception)
        render json: {
          error: "Erro de validação",
          errors: exception.record.errors.full_messages
        }, status: :unprocessable_entity
      end

      def handle_conflict(_exception)
        render json: {
          error: "Conflito de concorrência",
          message: "O registro foi modificado simultaneamente por outro operador. Por favor, recarregue a página antes de salvar."
        }, status: :conflict
      end
    end
  end
end
