# frozen_string_literal: true

Rails.application.configure do
  config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY") {
    Rails.application.credentials.dig(:active_record_encryption, :primary_key) || "b8e1a87a7821089debafcf98e1b458aab84831cce3c5ac71ea3c6026e9542350"
  }
  config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY") {
    Rails.application.credentials.dig(:active_record_encryption, :deterministic_key) || "6026e95423506db8e1a87a7821089debafcf98e1b458aab84831cce3c5ac71ea"
  }
  config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT") {
    Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt) || "debafcf98e1b458aab84831cce3c5ac71ea3c6026e95423506db8e1a87a78210"
  }
end
