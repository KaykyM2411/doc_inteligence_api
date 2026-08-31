# frozen_string_literal: true

require "base64"

module IntegracaoWhatsapp
  class WhatsappMedia
    attr_reader :media_id,
                :filename,
                :mime_type,
                :bytes,
                :url,
                :size

    def initialize(media_id: nil, filename: nil, mime_type: "application/octet-stream", bytes: nil, base64_content: nil, url: nil)
      @media_id = media_id.to_s.presence
      @filename = filename.to_s.presence || "whatsapp_media_#{Time.current.to_i}"
      @mime_type = mime_type.to_s
      @url = url.to_s.presence

      @bytes = if bytes.is_a?(String)
        bytes
      elsif bytes.respond_to?(:read)
        bytes.read
      elsif base64_content.present?
        Base64.decode64(base64_content) rescue ""
      else
        ""
      end

      @size = @bytes.bytesize
    end

    def has_bytes?
      @bytes.present? && @bytes.bytesize > 0
    end
  end
end
