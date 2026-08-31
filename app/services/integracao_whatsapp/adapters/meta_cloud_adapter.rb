# frozen_string_literal: true

require "faraday"
require "json"

module IntegracaoWhatsapp
  module Adapters
    class MetaCloudAdapter < Port
      GRAPH_API_BASE_URL = "https://graph.facebook.com/v20.0"

      def provider_name
        "meta_cloud"
      end

      # Processa o webhook oficial da Meta Cloud WhatsApp Business API
      # @param payload [Hash, ActionController::Parameters, String]
      # @return [WhatsappMessage]
      def parse_payload(payload)
        raw = payload.is_a?(String) ? JSON.parse(payload) : (payload.is_a?(ActionController::Parameters) ? payload.to_unsafe_h : (payload || {}))

        entry = (raw["entry"] || raw[:entry] || []).first || {}
        change = (entry["changes"] || entry[:changes] || []).first || {}
        value = change["value"] || change[:value] || {}

        message_item = (value["messages"] || value[:messages] || []).first || {}
        metadata = value["metadata"] || value[:metadata] || {}

        message_id = message_item["id"] || message_item[:id] || "meta_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
        sender_phone = message_item["from"] || message_item[:from] || ""
        receiver_phone = metadata["display_phone_number"] || metadata[:display_phone_number]
        timestamp = Time.at(message_item["timestamp"].to_i) rescue Time.current

        media = extract_media(message_item)
        caption = extract_caption(message_item)

        WhatsappMessage.new(
          provider_name: provider_name,
          reference_id: message_id,
          sender_phone: sender_phone.to_s.gsub(/\D/, ""),
          receiver_phone: receiver_phone,
          timestamp: timestamp,
          caption: caption,
          media: media,
          raw_payload: raw
        )
      end

      # Executa o fluxo obrigatório em 2 passos para baixar mídias da Graph API da Meta
      # Passo 1: Consulta GET https://graph.facebook.com/v20.0/{MEDIA_ID} para obter a URL temporária de download
      # Passo 2: Consulta GET na URL temporária com Authorization e User-Agent para obter o binário
      # @param media_id [String]
      # @param token [String, nil]
      # @return [String] Bytes binários do arquivo
      def download_media_bytes(media_id, token: nil)
        system_token = token.presence || resolve_meta_token
        return "" if media_id.blank? || system_token.blank?

        # Passo 1: Obter a URL temporária de download
        conn_graph = Faraday.new(url: GRAPH_API_BASE_URL) do |f|
          f.request :json
          f.response :json
          f.options.timeout = 15
          f.options.open_timeout = 5
        end

        res_info = conn_graph.get(media_id.to_s) do |req|
          req.headers["Authorization"] = "Bearer #{system_token}"
        end

        return "" unless res_info.success? && res_info.body.is_a?(Hash)

        temp_url = res_info.body["url"]
        return "" if temp_url.blank?

        # Passo 2: Baixar o binário puro da URL temporária (CDN da Meta exige User-Agent)
        conn_download = Faraday.new do |f|
          f.options.timeout = 60
          f.options.open_timeout = 10
        end

        res_binary = conn_download.get(temp_url) do |req|
          req.headers["Authorization"] = "Bearer #{system_token}"
          req.headers["User-Agent"] = "curl/7.64.1"
        end

        res_binary.success? ? res_binary.body : ""
      rescue StandardError => e
        Rails.logger.error("[MetaCloudAdapter] Falha no fluxo de download em 2 passos para a mídia #{media_id}: #{e.message}")
        ""
      end

      private

      def resolve_meta_token
        config = ConfiguracaoWhatsapp.find_by(tipo_provedor: "meta_cloud", ativo: true)
        config&.credencial_criptografada.presence || ENV["WHATSAPP_SYSTEM_USER_TOKEN"]
      end

      def extract_caption(message_item)
        msg_type = message_item["type"] || message_item[:type]
        item_data = message_item[msg_type] || message_item[msg_type&.to_sym] || {}
        item_data["caption"] || item_data[:caption] || message_item.dig("text", "body") || ""
      end

      def extract_media(message_item)
        msg_type = (message_item["type"] || message_item[:type]).to_s

        case msg_type
        when "document"
          doc = message_item["document"] || message_item[:document] || {}
          WhatsappMedia.new(
            media_id: doc["id"] || doc[:id],
            filename: doc["filename"] || doc[:filename] || "documento.pdf",
            mime_type: doc["mime_type"] || doc[:mime_type] || "application/pdf"
          )
        when "image"
          img = message_item["image"] || message_item[:image] || {}
          WhatsappMedia.new(
            media_id: img["id"] || img[:id],
            filename: "foto_meta_#{Time.current.to_i}.jpg",
            mime_type: img["mime_type"] || img[:mime_type] || "image/jpeg"
          )
        else
          nil
        end
      end
    end
  end
end
