# frozen_string_literal: true

require "base64"
require "json"

module ExtracaoIa
  class Port
    attr_reader :configuration

    def initialize(configuration = nil)
      @configuration = configuration
    end

    def provider_name
      raise NotImplementedError, "#{self.class} must implement #provider_name"
    end

    def model_name
      @configuration&.nome_modelo.presence || default_model
    end

    def default_model
      raise NotImplementedError, "#{self.class} must implement #default_model"
    end

    def credential
      @configuration&.credencial_criptografada.presence || env_credential
    end

    def env_credential
      nil
    end

    # Extract structured data from document
    # @param file_bytes_or_io [String, IO]
    # @param content_type [String]
    # @param options [Hash]
    # @return [ExtractionResult]
    def extract(file_bytes_or_io, content_type: "image/jpeg", options: {})
      raise NotImplementedError, "#{self.class} must implement #extract"
    end

    # Calculate token costs dynamically using the ConsultaPrecos Ports & Adapters domain
    # @param input_tokens [Integer]
    # @param output_tokens [Integer]
    # @param model [String, nil]
    # @return [Float]
    def calculate_estimated_cost(input_tokens, output_tokens, model = nil)
      pricing_adapter = ConsultaPrecos::Factory.for_provider(provider_name)
      pricing_adapter.calculate_cost(model || model_name, input_tokens, output_tokens, credential)
    end

    protected

    def prompt_version
      DefaultPrompt::VERSION
    end

    def encode_base64(bytes_or_io)
      if bytes_or_io.respond_to?(:read)
        Base64.strict_encode64(bytes_or_io.read)
      elsif bytes_or_io.is_a?(String)
        Base64.strict_encode64(bytes_or_io)
      else
        raise ArgumentError, "Invalid input for encode_base64: expected String or IO"
      end
    end

    def parse_json_response(text)
      return {} if text.blank?

      clean = text.strip.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "").strip
      JSON.parse(clean)
    rescue JSON::ParserError => e
      Rails.logger.error("[ExtracaoIa::#{self.class.name}] JSON parse error: #{e.message}. Snippet: #{text.to_s.truncate(200)}")
      {}
    end

    def measure_time
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed_ms = ((end_time - start_time) * 1000).round

      [ result, elapsed_ms ]
    end
  end
end
