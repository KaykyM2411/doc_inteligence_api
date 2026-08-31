# frozen_string_literal: true

module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json
        skip_before_action :verify_signed_out_user, only: :destroy

        # POST /api/v1/auth/login
        def create
          self.resource = warden.authenticate!(auth_options)
          sign_in(resource_name, resource)

          token = extract_jwt_token(resource)
          response.headers["Authorization"] = "Bearer #{token}" if token.present?

          render json: {
            mensagem: "Login realizado com sucesso",
            token: token,
            usuario: serialize_usuario(resource)
          }, status: :ok
        end

        # DELETE /api/v1/auth/logout
        def destroy
          if current_usuario
            sign_out(resource_name)
            render json: { mensagem: "Logout realizado com sucesso" }, status: :ok
          else
            render json: { mensagem: "Nenhuma sessão ativa encontrada" }, status: :ok
          end
        end

        # GET /api/v1/auth/me
        def show
          if current_usuario
            render json: { usuario: serialize_usuario(current_usuario) }, status: :ok
          else
            render json: { error: "Não autorizado" }, status: :unauthorized
          end
        end

        private

        def extract_jwt_token(user)
          request.env["warden-jwt_auth.token"] ||
            response.headers["Authorization"]&.sub(/\ABearer\s+/i, "") ||
            (Warden::JWTAuth::UserEncoder.new.call(user, :usuario, nil).first rescue nil)
        end

        def respond_to_on_destroy
          render json: { mensagem: "Logout realizado com sucesso" }, status: :ok
        end

        def serialize_usuario(usuario)
          {
            id: usuario.id,
            nome: usuario.nome,
            email: usuario.email,
            created_at: usuario.created_at
          }
        end
      end
    end
  end
end
