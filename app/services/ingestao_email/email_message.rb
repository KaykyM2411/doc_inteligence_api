# frozen_string_literal: true

module IngestaoEmail
  class EmailMessage
    attr_reader :provider_name,
                :reference_id,
                :sender_email,
                :recipient_email,
                :subject,
                :attachments,
                :raw_payload

    def initialize(
      provider_name:,
      reference_id:,
      sender_email:,
      recipient_email:,
      subject: nil,
      attachments: [],
      raw_payload: {}
    )
      @provider_name = provider_name.to_s
      @reference_id = reference_id.to_s.presence
      @sender_email = sender_email.to_s
      @recipient_email = recipient_email.to_s
      @subject = subject.to_s
      @attachments = Array(attachments)
      @raw_payload = raw_payload
    end

    def has_attachments?
      @attachments.any?
    end
  end
end
