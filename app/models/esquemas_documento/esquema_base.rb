# frozen_string_literal: true

module EsquemasDocumento
  class EsquemaBase
    include ActiveModel::Model
    include ActiveModel::Validations

    attr_accessor :dados_brutos

    def initialize(atributos = {})
      @dados_brutos = (atributos || {}).deep_stringify_keys
      super(sanitizar_atributos(@dados_brutos))
    end

    def nome_cliente
      nil
    end

    def cpf_cliente
      nil
    end

    def para_h
      as_json.compact
    end

    protected

    def sanitizar_atributos(hash)
      hash
    end

    def sanitizar_string(valor)
      return nil if valor.blank?

      valor.to_s.strip
    end

    def sanitizar_cpf(valor)
      return nil if valor.blank?

      digitos = valor.to_s.gsub(/\D/, "")
      return nil if digitos.length != 11

      "#{digitos[0..2]}.#{digitos[3..5]}.#{digitos[6..8]}-#{digitos[9..10]}"
    end

    def sanitizar_telefone(valor)
      return nil if valor.blank?

      digitos = valor.to_s.gsub(/\D/, "")
      digitos = digitos.sub(/\A55/, "") if digitos.length >= 12 && digitos.start_with?("55")

      if (match = digitos.match(/\A([1-9]{2})(\d{4,5})(\d{4})\z/))
        "(#{match[1]}) #{match[2]}-#{match[3]}"
      else
        digitos.presence
      end
    end

    def sanitizar_numero(valor)
      return nil if valor.blank?
      return valor.to_f if valor.is_a?(Numeric)

      # Trata separadores monetários com regex simples
      str = valor.to_s.gsub(/[^\d.,]/, "").strip
      str = str.gsub(".", "").tr(",", ".") if str.include?(",") && str.include?(".")
      str = str.tr(",", ".") if str.include?(",")

      str.to_f
    rescue StandardError
      nil
    end

    def sanitizar_data(valor)
      return nil if valor.blank?

      Date.parse(valor.to_s).strftime("%Y-%m-%d")
    rescue Date::Error, ArgumentError
      valor.to_s.strip
    end
  end
end
