# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documento, type: :model do
  let(:cliente) { Cliente.create!(nome: "Carlos Lima", cpf: "999.111.222-33") }
  let(:usuario) { Usuario.create!(nome: "Admin", email: "admin.doc@lamarck.adv.br", password: "Password@123") }

  describe "validations" do
    it "validates presence of mandatory fields" do
      doc = Documento.new
      expect(doc).not_to be_valid
      expect(doc.errors[:tipo]).to be_present
      expect(doc.errors[:origem]).to be_present
      expect(doc.errors[:sha256_arquivo]).to be_present
    end

    it "validates uniqueness of sha256 scoped to client when client is present" do
      Documento.create!(
        tipo: "rg",
        origem: "manual",
        sha256_arquivo: "abc123hash",
        cliente: cliente
      )

      dup = Documento.new(
        tipo: "rg",
        origem: "manual",
        sha256_arquivo: "abc123hash",
        cliente: cliente
      )

      expect(dup).not_to be_valid
      expect(dup.errors[:sha256_arquivo]).to be_present
    end

    it "allows same sha256 for different clients" do
      outro_cliente = Cliente.create!(nome: "Maria", cpf: "888.222.333-44")

      Documento.create!(
        tipo: "rg",
        origem: "manual",
        sha256_arquivo: "samehash123",
        cliente: cliente
      )

      outro_doc = Documento.new(
        tipo: "rg",
        origem: "manual",
        sha256_arquivo: "samehash123",
        cliente: outro_cliente
      )

      expect(outro_doc).to be_valid
    end
  end

  describe "associations" do
    it "belongs to optional client" do
      doc = Documento.new(tipo: "rg", origem: "manual", sha256_arquivo: "h1")
      expect(doc.cliente).to be_nil
      expect(doc).to be_valid
    end

    it "belongs to optional revisado_por as Usuario" do
      doc = Documento.create!(tipo: "rg", origem: "manual", sha256_arquivo: "h2", revisado_por: usuario)
      expect(doc.revisado_por).to eq(usuario)
    end

    it "has many historicos_extracao with dependent destroy" do
      doc = Documento.create!(tipo: "rg", origem: "manual", sha256_arquivo: "h3")
      doc.historicos_extracao.create!(
        nome_provedor: "grok",
        nome_modelo: "grok-2-vision-1212",
        versao_prompt: "v1.0"
      )

      expect { doc.destroy }.to change(HistoricoExtracao, :count).by(-1)
    end
  end

  describe "enums" do
    it "defines correct status enum values" do
      expect(Documento.statuses.keys).to contain_exactly(
        "pendente", "processando", "processado", "necessita_revisao", "falhou"
      )
    end

    it "defines correct origem enum values" do
      expect(Documento.defined_enums["origem"].keys).to contain_exactly("manual", "whatsapp", "email")
    end
  end

  describe "scopes" do
    it ".para_revisao returns only documents with status necessita_revisao or falhou" do
      doc1 = Documento.create!(tipo: "rg", origem: "manual", sha256_arquivo: "s1", status: :processado)
      doc2 = Documento.create!(tipo: "rg", origem: "manual", sha256_arquivo: "s2", status: :necessita_revisao)
      doc3 = Documento.create!(tipo: "rg", origem: "manual", sha256_arquivo: "s3", status: :falhou)

      revisao_ids = Documento.para_revisao.pluck(:id)
      expect(revisao_ids).to include(doc2.id, doc3.id)
      expect(revisao_ids).not_to include(doc1.id)
    end
  end
end
