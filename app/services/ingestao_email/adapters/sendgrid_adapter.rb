# frozen_string_literal: true

require "json"

module IngestaoEmail
  module Adapters
    class SendgridAdapter < Port
      def provider_name
        "sendgrid"
      end

      # Processa o webhook SendGrid Inbound Parse recebido via multipart/form-data
      # @param params [Hash, ActionController::Parameters]
      # @return [EmailMessage]
      def parse_payload(params)
        raw = params.is_a?(ActionController::Parameters) ? params.to_unsafe_h : (params || {})

        headers_str = raw["headers"] || raw[:headers] || ""
        envelope_str = raw["envelope"] || raw[:envelope] || ""
        envelope_data = parse_json_safely(envelope_str)

        message_id = extract_message_id(headers_str) ||
                     envelope_data["message_id"] ||
                     raw["email_id"] ||
                     "sendgrid_#{Time.current.to_i}_#{SecureRandom.hex(4)}"

        from = raw["from"] || raw[:from] || envelope_data["from"] || ""
        to = raw["to"] || raw[:to] || (envelope_data["to"].is_a?(Array) ? envelope_data["to"].first : envelope_data["to"]) || ""
        subject = raw["subject"] || raw[:subject] || ""

        attachment_info_str = raw["attachment-info"] || raw[:"attachment-info"] || "{}"
        attachment_info = parse_json_safely(attachment_info_str)

        total_attachments = (raw["attachments"] || raw[:attachments] || 0).to_i
        attachments = extract_multipart_attachments(raw, attachment_info, total_attachments)

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

      def parse_json_safely(str)
        return {} if str.blank?
        return str if str.is_a?(Hash)

        JSON.parse(str)
      rescue JSON::ParserError
        {}
      end

      def extract_message_id(headers_str)
        return nil if headers_str.blank?

        match = headers_str.match(/Message-ID:\s*<([^>]+)>/i) ||
                headers_str.match(/Message-Id:\s*<([^>]+)>/i)
        match ? match[1] : nil
      end

      def extract_multipart_attachments(raw, attachment_info, total_count)
        attachments = []

        # 1. Varre campos attachment1, attachment2, ... attachmentN conforme especificação SendGrid
        raw.each do |key, value|
          key_str = key.to_s
          next unless key_str.match?(/\Aattachment\d+\z/i)

          meta = attachment_info[key_str] || attachment_info[key_str.to_sym] || {}

          filename = meta["filename"] || meta[:filename] ||
                     (value.respond_to?(:original_filename) ? value.original_filename : nil) ||
                     "anexo_#{key_str}.bin"

          content_type = meta["type"] || meta[:type] ||
                         (value.respond_to?(:content_type) ? value.content_type : nil) ||
                         "application/octet-stream"

          bytes = extract_bytes_from_value(value)

          attachments << EmailAttachment.new(
            filename: filename,
            content_type: content_type,
            bytes: bytes
          )
        end

        # 2. Suporte para arrays diretos de uploads (ActionDispatch::Http::UploadedFile)
        if raw["attachments"].is_a?(Array)
          raw["attachments"].each_with_index do |att, idx|
            next unless att.respond_to?(:read)

            filename = att.respond_to?(:original_filename) ? att.original_filename : "anexo_#{idx + 1}.bin"
            content_type = att.respond_to?(:content_type) ? att.content_type : "application/octet-stream"

            attachments << EmailAttachment.new(
              filename: filename,
              content_type: content_type,
              bytes: att.read
            )
          end
        end

        attachments
      end

      def extract_bytes_from_value(value)
        if value.respond_to?(:read)
          value.rewind if value.respond_to?(:rewind)
          value.read
        elsif value.is_a?(String)
          value
        elsif value.is_a?(Hash) && value["content"]
          value["content"]
        else
          ""
        end
      end
    end
  end
end
