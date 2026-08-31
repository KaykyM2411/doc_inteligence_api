# frozen_string_literal: true

require "json"
require "faraday"

class PopularEstadosECidades < ActiveRecord::Migration[8.1]
  ESTADOS_URL = "https://raw.githubusercontent.com/kelvins/municipios-brasileiros/main/json/estados.json"
  MUNICIPIOS_URL = "https://raw.githubusercontent.com/kelvins/municipios-brasileiros/main/json/municipios.json"

  def up
    estados_json = carregar_json("estados.json", ESTADOS_URL)
    municipios_json = carregar_json("municipios.json", MUNICIPIOS_URL)

    # 1. Inserir Estados
    codigo_uf_to_estado_id = {}

    estados_json.each do |est|
      estado = Estado.find_or_create_by!(sigla: est["uf"]) do |e|
        e.nome = est["nome"]
      end
      codigo_uf_to_estado_id[est["codigo_uf"]] = estado.id
    end

    # 2. Inserir Municípios em Lotes para Alta Performance
    cidades_records = municipios_json.map do |muni|
      estado_id = codigo_uf_to_estado_id[muni["codigo_uf"]]
      next nil unless estado_id

      {
        estado_id: estado_id,
        nome: muni["nome"]
      }
    end.compact

    cidades_records.each_slice(1000) do |batch|
      Cidade.insert_all(batch)
    end

    puts "== PopularEstadosECidades: #{Estado.count} estados e #{Cidade.count} cidades inseridos com sucesso =="
  end

  def down
    Cidade.delete_all
    Estado.delete_all
  end

  private

  def carregar_json(nome_arquivo, url)
    caminho_local = Rails.root.join("db", "data_sources", nome_arquivo)

    conteudo = if File.exist?(caminho_local)
                 File.read(caminho_local)
    else
                 response = Faraday.get(url)
                 response.body
    end

    limpo = conteudo.force_encoding("UTF-8").sub(/\A\xEF\xBB\xBF/, "")
    JSON.parse(limpo)
  end
end
