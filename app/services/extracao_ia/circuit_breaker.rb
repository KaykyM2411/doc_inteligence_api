# frozen_string_literal: true

require "redis"

module ExtracaoIa
  class CircuitOpenError < StandardError; end

  class CircuitBreaker
    FAILURE_THRESHOLD = 5      # Abre o circuito após 5 falhas consecutivas
    RESET_TIMEOUT     = 120    # Janela de cooldown em segundos (2 minutos)
    REDIS_PREFIX      = "circuit_breaker:extracao_ia"

    attr_reader :provider_name, :redis

    def initialize(provider_name, redis: nil)
      @provider_name = provider_name.to_s
      @redis = redis || self.class.default_redis
    end

    def self.default_redis
      @default_redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    end

    # Executa a chamada protegida pelo Circuit Breaker
    def call
      if open?
        raise CircuitOpenError, "Provedor '#{provider_name}' indisponível no momento (Circuit Breaker: OPEN)"
      end

      begin
        result = yield

        # Se o resultado for um objeto que responde a success?, verifica se foi bem-sucedido
        if result.respond_to?(:success?) && !result.success? && network_or_service_error?(result)
          record_failure!
        else
          record_success!
        end

        result
      rescue StandardError => e
        record_failure!
        raise e
      end
    end

    def state
      current_state = safe_redis_get(state_key)

      if current_state == "open"
        # Se a chave de falhas já expirou o TTL de cooldown, passamos para half_open
        safe_redis_exists?(fails_key) ? :open : :half_open
      else
        :closed
      end
    end

    def open?
      state == :open
    end

    def half_open?
      state == :half_open
    end

    def closed?
      state == :closed
    end

    def record_failure!
      # Incrementa o contador atômico de falhas
      fails = safe_redis_incr(fails_key)
      safe_redis_expire(fails_key, RESET_TIMEOUT)

      if fails >= FAILURE_THRESHOLD
        safe_redis_set(state_key, "open", ex: RESET_TIMEOUT)
        log_warn("[CircuitBreaker] Disjuntor aberto para '#{provider_name}' apos #{fails} falhas consecutivas.")
      end
    end

    def record_success!
      safe_redis_del(state_key)
      safe_redis_del(fails_key)
    end

    def reset!
      record_success!
    end

    private

    def state_key
      "#{REDIS_PREFIX}:#{provider_name}:state"
    end

    def fails_key
      "#{REDIS_PREFIX}:#{provider_name}:failures"
    end

    def network_or_service_error?(result)
      msg = result.error_message.to_s.downcase
      msg.include?("timeout") || msg.include?("conexão") || msg.include?("connection") || msg.include?("503") || msg.include?("502") || msg.include?("504") || msg.include?("429")
    end

    def safe_redis_get(key)
      @redis.get(key)
    rescue StandardError => e
      log_error("[CircuitBreaker] Erro ao consultar Redis: #{e.message}")
      nil
    end

    def safe_redis_exists?(key)
      @redis.exists?(key)
    rescue StandardError => e
      log_error("[CircuitBreaker] Erro ao consultar Redis exists: #{e.message}")
      false
    end

    def safe_redis_set(key, val, ex:)
      @redis.set(key, val, ex: ex)
    rescue StandardError => e
      log_error("[CircuitBreaker] Erro ao gravar Redis: #{e.message}")
    end

    def safe_redis_incr(key)
      @redis.incr(key)
    rescue StandardError => e
      log_error("[CircuitBreaker] Erro ao incrementar Redis: #{e.message}")
      1
    end

    def safe_redis_expire(key, seconds)
      @redis.expire(key, seconds)
    rescue StandardError => e
      log_error("[CircuitBreaker] Erro ao definir TTL no Redis: #{e.message}")
    end

    def safe_redis_del(*keys)
      @redis.del(*keys)
    rescue StandardError => e
      log_error("[CircuitBreaker] Erro ao deletar do Redis: #{e.message}")
    end

    def log_warn(msg)
      Rails.logger.warn(msg) if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
    end

    def log_error(msg)
      Rails.logger.error(msg) if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
    end
  end
end
