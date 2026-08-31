# frozen_string_literal: true

require "base64"
require "json"

module IngestaoEmail
  module Adapters
    class PostmarkAdapter < Port
      def provider_name
        "postmark"
      end

      # Processa o webhook Postmark Inbound recebido em formato JSON
      # @param payload [Hash, ActionController::Parameters, String]
      # @return [EmailMessage]
      def parse_payload(payload)
        raw = payload.is_a?(String) ? JSON.parse(payload) : (payload.is_a?(ActionController::Parameters) ? payload.to_unsafe_h : (payload || {}))

        message_id = raw["MessageID"] || raw[:MessageID] || extract_header_message_id(raw["Headers"] || raw[:Headers]) || "postmark_#{Time.current.to_i}_#{SecureRandom.hex(4)}"

        from = extract_email(raw["From"] || raw[:From] || raw["FromFull"] || raw[:FromFull])
        to = extract_email(raw["To"] || raw[:To] || raw["ToFull"] || raw[:ToFull])
        subject = raw["Subject"] || raw[:Subject] || ""

        attachments = extract_attachments(raw["Attachments"] || raw[:Attachments] || [])

        EmailMessage.new(
          provider_name: provider_name,
          reference_id: message_id,
          sender_email: from,
          recipient_email: to,
          subject: subject,
          attachments: attachments,
          raw_payload: raw
        )
      end

      private

      def extract_email(field)
        return "" if field.blank?
        return field if field.is_a?(String)

        if field.is_a?(Hash)
          field["Email"] || field[:Email] || ""
        elsif field.is_a?(Array) && field.first.is_a?(Hash)
          field.first["Email"] || field.first[:Email] || ""
        else
          field.to_s
        end
      end

      def extract_header_message_id(headers)
        return nil unless headers.is_a?(Array)

        item = headers.find { |h| (h["Name"] || h[:Name]).to_s.casecmp("Message-ID").zero? }
        item ? (item["Value"] || item[:Value]) : nil
      end

      def extract_attachments(attachments_raw)
        return [] unless attachments_raw.is_a?(Array)

        attachments_raw.map do |att|
          content_base64 = att["Content"] || att[:Content] || ""
          bytes = Base64.decode64(content_base64) rescue ""

          EmailAttachment.new(
            filename: att["Name"] || att[:Name] || "anexo_postmark.bin",
            content_type: att["ContentType"] || att[:ContentType] || "application/octet-stream",
            bytes: bytes
          )
        end
      end
    end
  end
end
