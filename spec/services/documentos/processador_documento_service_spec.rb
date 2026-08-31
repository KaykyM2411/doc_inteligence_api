# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documentos::ProcessadorDocumentoService, type: :service do
  let!(:cliente) do
    Cliente.create!(
      nome: "Maria Silva Santos",
      cpf: "123.456.789-00",
      email: "maria@example.com"
    )
  end

  let!(:documento) do
    Documento.create!(
      tipo: "rg",
      origem: "manual",
      sha256_arquivo: Digest::SHA256.hexdigest("conteudo_simulado_documento"),
      url_arquivo_bruto: "conteudo_simulado_documento",
      status: :pendente
    )
  end

  let(:mock_adapter) { ExtracaoIa::Adapters::MockAdapter.new }

  subject(:service) { described_class.new(documento, adapter: mock_adapter) }

  describe "#processar!" do
    context "when extraction succeeds and schema is valid" do
      it "extracts data, validates schema, associates existing client and marks as processado" do
        processed_doc = service.processar!

        expect(processed_doc.status).to eq("processado")
        expect(processed_doc.cliente).to eq(cliente)
        expect(processed_doc.dados_extraidos["nome"]).to eq("Maria Silva Santos")
        expect(processed_doc.dados_extraidos["cpf"]).to eq("123.456.789-00")
        expect(processed_doc.score_confianca).to be >= 0.85

        historico = processed_doc.historicos_extracao.last
        expect(historico).to be_present
        expect(historico.nome_provedor).to eq("mock")
        expect(historico.tokens_entrada).to be > 0
      end
    end

    context "when extracted confidence is low or schema is unknown" do
      it "marks document as necessita_revisao" do
        allow(mock_adapter).to receive(:extract).and_return(
          ExtracaoIa::ExtractionResult.new(
            success: true,
            provider_name: "mock",
            model_name: "mock-vision-v1",
            document_type: "desconhecido",
            confidence_score: 0.40,
            extracted_data: {}
          )
        )

        processed_doc = service.processar!
        expect(processed_doc.status).to eq("necessita_revisao")
      end
    end

    context "when AI extraction fails" do
      it "marks document as falhou and logs error in historicos_extracao" do
        allow(mock_adapter).to receive(:extract).and_return(
          ExtracaoIa::ExtractionResult.new(
            success: false,
            provider_name: "mock",
            model_name: "mock-vision-v1",
            error_message: "Network Timeout"
          )
        )

        processed_doc = service.processar!
        expect(processed_doc.status).to eq("falhou")
        expect(processed_doc.historicos_extracao.last.mensagem_erro).to eq("Network Timeout")
      end
    end
  end
end
