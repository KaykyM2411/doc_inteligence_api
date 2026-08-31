# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Documentação Swagger UI
  get "api-docs", to: "api_docs#index"
  get "swagger.json", to: "api_docs#swagger_json"

  # Servidor WebSocket do ActionCable
  mount ActionCable.server => "/cable"

  devise_for :usuarios, skip: :all

  namespace :api do
    namespace :v1 do
      # Autenticação JWT
      devise_scope :usuario do
        post "auth/login", to: "auth/sessions#create"
        delete "auth/logout", to: "auth/sessions#destroy"
        get "auth/me", to: "auth/sessions#show"
      end

      # Webhooks Públicos com autenticação dinâmica
      namespace :webhooks do
        post "whatsapp/:provider", to: "whatsapp#create"
        post "whatsapp", to: "whatsapp#create"
        get "whatsapp/:provider", to: "whatsapp#verify"
        get "whatsapp", to: "whatsapp#verify"

        post "email/:provider", to: "email#create"
        post "email", to: "email#create"
      end

      # Clientes & Ficha do Cliente
      resources :clientes do
        member do
          get :documentos
          post :documentos, to: "clientes#upload_documento"
        end
      end

      # Documentos & Fila de Conferência Humana
      resources :documentos, only: [ :index, :show, :create ] do
        collection do
          get :fila_conferencia
        end
        member do
          patch :revisar
          get :download
        end
      end

      # Notificações do Sistema
      resources :notificacoes, only: [ :index, :show ] do
        member do
          patch :lida
        end
        collection do
          post :marcar_todas_lidas
          get :nao_lidas_count
        end
      end

      # Base Geográfica (Estados e Cidades)
      resources :estados, only: [ :index, :show ] do
        resources :cidades, only: [ :index ]
      end
      resources :cidades, only: [ :index, :show ]

      # Configurações de Integração
      namespace :configuracoes do
        resources :provedores_ia, only: [ :index, :show, :update ] do
          member do
            post :ativar
          end
        end
        resources :whatsapp, only: [ :index, :show, :create, :update, :destroy ]
        resources :smtp, only: [ :index, :show, :create, :update, :destroy ]
      end

      # Auditoria de Custos de IA
      namespace :auditoria do
        get "custos", to: "custos#index"
      end
    end
  end
end
