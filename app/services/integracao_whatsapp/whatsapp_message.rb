# frozen_string_literal: true

module IntegracaoWhatsapp
  class WhatsappMessage
    attr_reader :provider_name,
                :reference_id,
                :sender_phone,
                :receiver_phone,
                :timestamp,
                :caption,
                :media,
                :raw_payload

    def initialize(
      provider_name:,
      reference_id:,
      sender_phone:,
      receiver_phone: nil,
      timestamp: nil,
      caption: nil,
      media: nil,
      raw_payload: {}
    )
      @provider_name = provider_name.to_s
      @reference_id = reference_id.to_s.presence
      @sender_phone = sender_phone.to_s
      @receiver_phone = receiver_phone.to_s.presence
      @timestamp = timestamp || Time.current
      @caption = caption.to_s
      @media = media
      @raw_payload = raw_payload
    end

    def has_media?
      @media.present?
    end
  end
end
