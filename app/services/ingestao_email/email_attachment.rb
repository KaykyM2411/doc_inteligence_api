# frozen_string_literal: true

module IngestaoEmail
  class EmailAttachment
    attr_reader :filename, :content_type, :bytes, :size

    def initialize(filename:, content_type:, bytes:)
      @filename = filename.to_s
      @content_type = content_type.to_s
      @bytes = bytes.is_a?(String) ? bytes : (bytes.respond_to?(:read) ? bytes.read : "")
      @size = @bytes.bytesize
    end
  end
end
