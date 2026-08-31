# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notificacoes::EmissorNotificacaoService, type: :service do
  let!(:cliente) { Cliente.create!(nome: "Mariana Costa", cpf: "123.456.789-11") }

  let(:doc_whatsapp) do
    Documento.create!(
      tipo: "cnh",
      origem: "whatsapp",
      status: :processado,
      nome_arquivo: "cnh_mariana.pdf",
      score_confianca: 0.95,
      sha256_arquivo: Digest::SHA256.hexdigest("wa_file"),
      cliente: cliente
    )
  end

  let(:doc_manual) do
    Documento.create!(
      tipo: "rg",
      origem: "manual",
      status: :processado,
      sha256_arquivo: Digest::SHA256.hexdigest("manual_file")
    )
  end

  describe ".notificar_documento_integracao!" do
    it "persists notification and broadcasts via ActionCable for whatsapp documents" do
      expect {
        described_class.notificar_documento_integracao!(doc_whatsapp)
      }.to change(Notificacao, :count).by(1)

      notificacao = Notificacao.last
      expect(notificacao.titulo).to eq("Novo documento recebido via WhatsApp")
      expect(notificacao.conteudo).to include("cnh_mariana.pdf")
      expect(notificacao.metadados["documento_id"]).to eq(doc_whatsapp.id)
      expect(notificacao.metadados["score_confianca"]).to eq(0.95)
      expect(notificacao.metadados["cliente_nome"]).to eq("Mariana Costa")
    end

    it "does not emit notification for manual uploads" do
      expect {
        resultado = described_class.notificar_documento_integracao!(doc_manual)
        expect(resultado).to be_nil
      }.not_to change(Notificacao, :count)
    end
  end
end
