# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cliente, type: :model do
  let!(:estado) { Estado.find_or_create_by!(sigla: "RN") { |e| e.nome = "Rio Grande do Norte" } }
  let!(:cidade) { Cidade.find_or_create_by!(nome: "Mossoró", estado: estado) }

  describe "validations" do
    it "validates presence of nome" do
      cliente = Cliente.new
      expect(cliente).not_to be_valid
      expect(cliente.errors[:nome]).to be_present
    end

    it "validates uniqueness of CPF" do
      Cliente.create!(nome: "Cliente Um", cpf: "123.456.789-00")
      dup = Cliente.new(nome: "Cliente Dois", cpf: "123.456.789-00")

      expect(dup).not_to be_valid
      expect(dup.errors[:cpf]).to be_present
    end

    it "allows nil CPF" do
      c1 = Cliente.create!(nome: "Sem CPF 1", cpf: nil)
      c2 = Cliente.new(nome: "Sem CPF 2", cpf: nil)

      expect(c1).to be_persisted
      expect(c2).to be_valid
    end
  end

  describe "associations" do
    it "has many enderecos with dependent destroy" do
      cliente = Cliente.create!(nome: "Cliente Com Endereço")
      cliente.enderecos.create!(logradouro: "Rua Melo Franco", numero: "122", cidade: cidade)

      expect { cliente.destroy }.to change(Endereco, :count).by(-1)
    end

    it "has many documentos with dependent nullify" do
      cliente = Cliente.create!(nome: "Cliente Com Doc")
      doc = Documento.create!(
        tipo: "rg",
        origem: "manual",
        sha256_arquivo: "sha_cliente_assoc_test",
        cliente: cliente
      )

      cliente.destroy
      expect(doc.reload.cliente_id).to be_nil
    end
  end
end
