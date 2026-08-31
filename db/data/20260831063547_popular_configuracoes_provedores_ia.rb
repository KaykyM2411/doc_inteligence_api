# frozen_string_literal: true

class PopularConfiguracoesProvedoresIa < ActiveRecord::Migration[8.1]
  PROVEDORES = [
    {
      nome_provedor: "grok",
      nome_modelo: "grok-2-vision-1212",
      credencial: ENV["XAI_API_KEY"] || "xai-RPQMM5i4coQfOdNxlRyWiPHXsC1ZAjHa9EfextbhWhVTITZi0J1E2VOCaxkrGLbqxCkf6Yi7JgEMYw0j",
      ativo: true
    },
    {
      nome_provedor: "openai",
      nome_modelo: "gpt-4o-mini",
      credencial: ENV["OPENAI_API_KEY"] || "sk-openai-placeholder-key",
      ativo: false
    },
    {
      nome_provedor: "gemini",
      nome_modelo: "gemini-1.5-flash",
      credencial: ENV["GEMINI_API_KEY"] || "gemini-placeholder-key",
      ativo: false
    },
    {
      nome_provedor: "openrouter",
      nome_modelo: "meta-llama/llama-3.2-11b-vision-instruct",
      credencial: ENV["OPENROUTER_API_KEY"] || "sk-or-placeholder-key",
      ativo: false
    },
    {
      nome_provedor: "ollama",
      nome_modelo: "llama3.2-vision",
      credencial: "http://localhost:11434",
      ativo: false
    },
    {
      nome_provedor: "mock",
      nome_modelo: "mock-vision-v1",
      credencial: "mock-deterministic-key",
      ativo: false
    }
  ].freeze

  def up
    PROVEDORES.each do |p|
      config = ConfiguracaoProvedorIa.find_or_initialize_by(nome_provedor: p[:nome_provedor])
      config.nome_modelo = p[:nome_modelo]
      config.credencial_criptografada = p[:credencial]
      config.ativo = p[:ativo]
      config.save!
    end

    puts "== PopularConfiguracoesProvedoresIa: #{ConfiguracaoProvedorIa.count} provedores de IA configurados =="
  end

  def down
    ConfiguracaoProvedorIa.delete_all
  end
end
