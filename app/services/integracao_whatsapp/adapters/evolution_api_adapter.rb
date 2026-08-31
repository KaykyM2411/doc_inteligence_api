# frozen_string_literal: true

require "json"

module IntegracaoWhatsapp
  module Adapters
    class EvolutionApiAdapter < Port
      def provider_name
        "evolution_api"
      end

      # Processa o webhook oficial da Evolution API (evento messages.upsert)
      # @param payload [Hash, ActionController::Parameters, String]
      # @return [WhatsappMessage]
      def parse_payload(payload)
        raw = payload.is_a?(String) ? JSON.parse(payload) : (payload.is_a?(ActionController::Parameters) ? payload.to_unsafe_h : (payload || {}))

        data = raw["data"] || raw[:data] || raw
        key = data["key"] || data[:key] || {}
        message_wrapper = data["message"] || data[:message] || {}

        message_id = key["id"] || key[:id] || "evo_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
        remote_jid = key["remoteJid"] || key[:remoteJid] || raw["sender"] || raw[:sender] || ""
        sender_phone = sanitize_phone(remote_jid)

        instance_name = raw["instance"] || raw[:instance] || data["instanceId"] || data[:instanceId]
        timestamp = Time.at(data["messageTimestamp"].to_i) rescue Time.current

        media = extract_media(message_wrapper, data)
        caption = extract_caption(message_wrapper)

        WhatsappMessage.new(
          provider_name: provider_name,
          reference_id: message_id,
          sender_phone: sender_phone,
          receiver_phone: instance_name,
          timestamp: timestamp,
          caption: caption,
          media: media,
          raw_payload: raw
        )
      end

      private

      def sanitize_phone(remote_jid)
        remote_jid.to_s.gsub(/@.+/, "").gsub(/\D/, "")
      end

      def extract_caption(message_wrapper)
        doc = message_wrapper["documentMessage"] || message_wrapper[:documentMessage]
        img = message_wrapper["imageMessage"] || message_wrapper[:imageMessage]

        doc&.dig("caption") || doc&.dig(:caption) ||
          img&.dig("caption") || img&.dig(:caption) ||
          message_wrapper["conversation"] || message_wrapper[:conversation] || ""
      end

      def extract_media(message_wrapper, data)
        # O base64 pode vir na raiz de data.message ou aninhado dentro do tipo de mensagem
        root_base64 = message_wrapper["base64"] || message_wrapper[:base64]

        if (doc = message_wrapper["documentMessage"] || message_wrapper[:documentMessage])
          base64_content = doc["base64"] || doc[:base64] || root_base64
          WhatsappMedia.new(
            media_id: doc["id"] || doc[:id] || doc["mediaKey"] || doc[:mediaKey],
            filename: doc["fileName"] || doc[:fileName] || doc["title"] || doc[:title] || "documento.pdf",
            mime_type: doc["mimetype"] || doc[:mimetype] || "application/pdf",
            base64_content: base64_content,
            url: doc["url"] || doc[:url]
          )
        elsif (img = message_wrapper["imageMessage"] || message_wrapper[:imageMessage])
          base64_content = img["base64"] || img[:base64] || root_base64
          WhatsappMedia.new(
            media_id: img["id"] || img[:id] || img["mediaKey"] || img[:mediaKey],
            filename: "foto_whatsapp_#{Time.current.to_i}.jpg",
            mime_type: img["mimetype"] || img[:mimetype] || "image/jpeg",
            base64_content: base64_content,
            url: img["url"] || img[:url]
          )
        end
      end
    end
  end
end
