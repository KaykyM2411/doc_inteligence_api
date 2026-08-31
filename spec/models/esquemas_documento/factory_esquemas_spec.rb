# frozen_string_literal: true

require "rails_helper"

RSpec.describe EsquemasDocumento::FactoryEsquemas, type: :model do
  describe ".build" do
    context "when type is rg" do
      it "validates, sanitizes CPF and extracts client attributes" do
        raw_payload = {
          "nome" => "  Maria Silva Santos  ",
          "cpf" => "12345678900",
          "numero_rg" => " 002.894.123 ",
          "orgao_emissor" => "SSP/RN",
          "data_nascimento" => "1990-05-15",
          "filiacao" => { "mae" => "Ana Silva", "pai" => "Carlos Santos" }
        }

        schema = described_class.build("rg", raw_payload, 1)

        expect(schema).to be_a(EsquemasDocumento::EsquemaRgV1)
        expect(schema).to be_valid
        expect(schema.nome_cliente).to eq("Maria Silva Santos")
        expect(schema.cpf_cliente).to eq("123.456.789-00")
        expect(schema.numero_rg).to eq("002.894.123")
      end

      it "is invalid when required fields are missing" do
        schema = described_class.build("rg", {}, 1)
        expect(schema).not_to be_valid
        expect(schema.errors[:nome]).to be_present
        expect(schema.errors[:numero_rg]).to be_present
      end
    end

    context "when type is cnh" do
      it "validates and formats CNH fields" do
        raw_payload = {
          "nome" => "João Pereira",
          "cpf" => "111.222.333-44",
          "numero_cnh" => "98765432100",
          "categoria" => "AB"
        }

        schema = described_class.build("cnh", raw_payload, 1)

        expect(schema).to be_a(EsquemasDocumento::EsquemaCnhV1)
        expect(schema).to be_valid
        expect(schema.nome_cliente).to eq("João Pereira")
        expect(schema.cpf_cliente).to eq("111.222.333-44")
      end

      it "is invalid when CPF is missing" do
        schema = described_class.build("cnh", { "nome" => "João", "numero_cnh" => "123" }, 1)
        expect(schema).not_to be_valid
        expect(schema.errors[:cpf]).to be_present
      end
    end

    context "when type is comprovante_residencia" do
      it "validates address and extracts titular" do
        raw_payload = {
          "titular" => "Pedro Alcantara",
          "cpf_titular" => "555.666.777-88",
          "tipo_comprovante" => "energia",
          "empresa_emissora" => "Cosern",
          "endereco" => {
            "logradouro" => "Rua Melo Franco",
            "numero" => "122",
            "cidade" => "Mossoró",
            "estado" => "RN",
            "cep" => "59600-165"
          }
        }

        schema = described_class.build("comprovante_residencia", raw_payload, 1)

        expect(schema).to be_a(EsquemasDocumento::EsquemaComprovanteResidenciaV1)
        expect(schema).to be_valid
        expect(schema.nome_cliente).to eq("Pedro Alcantara")
        expect(schema.cpf_cliente).to eq("555.666.777-88")
        expect(schema.endereco["cidade"]).to eq("Mossoró")
      end
    end

    context "when type is contracheque" do
      it "validates employee name and salary numbers" do
        raw_payload = {
          "nome_funcionario" => "Ana Beatriz",
          "cpf_funcionario" => "999.888.777-66",
          "empregador" => "Lamarck Advogados",
          "salario_bruto" => "R$ 5.500,00",
          "salario_liquido" => "4.200,50"
        }

        schema = described_class.build("contracheque", raw_payload, 1)

        expect(schema).to be_a(EsquemasDocumento::EsquemaContrachequeV1)
        expect(schema).to be_valid
        expect(schema.nome_cliente).to eq("Ana Beatriz")
        expect(schema.cpf_cliente).to eq("999.888.777-66")
        expect(schema.salario_liquido).to eq(4200.50)
      end
    end
  end
end
