# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_usuario

    def connect
      self.current_usuario = find_verified_usuario
    end

    private

    def find_verified_usuario
      token = request.params[:token] || request.headers["Authorization"]&.sub(/\ABearer\s+/i, "")

      if token.present?
        payload = Warden::JWTAuth::TokenDecoder.new.call(token) rescue nil
        if payload && (usuario = Usuario.find_by(id: payload["sub"]))
          return usuario
        end
      end

      # Rejeita conexões sem autenticação JWT válida
      reject_unauthorized_connection
    end
  end
end
