# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documentos::IngestaoService, type: :service do
  include ActiveJob::TestHelper

  let(:pdf_bytes) { "%PDF-1.4 sample pdf content for ingestion testing" }
  let(:invalid_bytes) { "MZ\x90\x00\x03executavel" }

  let(:cliente) do
    Cliente.create!(
      nome: "Carlos Eduardo",
      cpf: "123.456.789-00",
      email: "carlos@example.com"
    )
  end

  before do
    clear_enqueued_jobs
  end

  describe ".ingestar!" do
    context "when file is valid and new" do
      it "persists document, attaches file, calculates SHA-256 and enqueues ProcessarDocumentoJob" do
        resultado = described_class.ingestar!(
          pdf_bytes,
          origem: :manual,
          nome_arquivo: "meu_comprovante.pdf"
        )

        expect(resultado).to be_sucesso
        expect(resultado.duplicado).to be false
        expect(resultado.documento).to be_persisted
        expect(resultado.documento.status).to eq("pendente")
        expect(resultado.documento.origem).to eq("manual")
        expect(resultado.documento.sha256_arquivo).to eq(Digest::SHA256.hexdigest(pdf_bytes))
        expect(resultado.documento.arquivo).to be_attached

        expect(enqueued_jobs.size).to eq(1)
        expect(enqueued_jobs.first[:job]).to eq(ProcessarDocumentoJob)
      end
    end

    context "when client_id is provided directly (ficha do cliente)" do
      it "associates document directly with the specified client" do
        resultado = described_class.ingestar!(
          pdf_bytes,
          origem: :manual,
          nome_arquivo: "rg_carlos.pdf",
          cliente_id: cliente.id
        )

        expect(resultado).to be_sucesso
        expect(resultado.documento.cliente_id).to eq(cliente.id)
      end

      it "detects SHA-256 content duplication for the same client and returns existing document without duplicating" do
        primeiro = described_class.ingestar!(
          pdf_bytes,
          origem: :manual,
          nome_arquivo: "rg_carlos.pdf",
          cliente_id: cliente.id
        )

        segundo = described_class.ingestar!(
          pdf_bytes,
          origem: :manual,
          nome_arquivo: "outro_nome_mas_mesmo_arquivo.pdf",
          cliente_id: cliente.id
        )

        expect(segundo.duplicado).to be true
        expect(segundo.duplicata_cliente?).to be true
        expect(segundo.documento.id).to eq(primeiro.documento.id)
        expect(Documento.where(cliente_id: cliente.id).count).to eq(1)
      end
    end

    context "when webhook reference is present (Early Idempotency)" do
      it "returns existing document immediately when the same event is received again" do
        primeiro = described_class.ingestar!(
          pdf_bytes,
          origem: :whatsapp,
          referencia_origem: "wamid.1234567890",
          nome_arquivo: "cnh_zap.pdf"
        )

        expect(primeiro.duplicado).to be false

        segundo = described_class.ingestar!(
          pdf_bytes,
          origem: :whatsapp,
          referencia_origem: "wamid.1234567890",
          nome_arquivo: "cnh_zap.pdf"
        )

        expect(segundo.duplicado).to be true
        expect(segundo.idempotente?).to be true
        expect(segundo.documento.id).to eq(primeiro.documento.id)
        expect(Documento.where(referencia_origem: "wamid.1234567890").count).to eq(1)
      end
    end

    context "when file is invalid or malicious" do
      it "raises ErroArquivoInvalido and does not persist document" do
        expect {
          described_class.ingestar!(
            invalid_bytes,
            origem: :manual,
            nome_arquivo: "virus.exe"
          )
        }.to raise_error(Documentos::IngestaoService::ErroArquivoInvalido, /não permitido/)

        expect(Documento.count).to eq(0)
      end
    end
  end
end
