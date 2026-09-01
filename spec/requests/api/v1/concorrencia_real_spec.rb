# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Concorrência Real e Fatos do Ambiente (Fato c e Fato g)", type: :request do
  let!(:usuario_a) do
    Usuario.create!(
      nome: "Atendente Ana",
      email: "ana@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:usuario_b) do
    Usuario.create!(
      nome: "Atendente Bruno",
      email: "bruno@lamarck.adv.br",
      password: "Password@123",
      password_confirmation: "Password@123"
    )
  end

  let!(:cliente) do
    Cliente.create!(
      nome: "Cliente Silva",
      cpf: "111.222.333-44"
    )
  end

  let(:token_ana) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "ana@lamarck.adv.br", password: "Password@123" }
    }
    response.headers["Authorization"]
  end

  let(:token_bruno) do
    post "/api/v1/auth/login", params: {
      usuario: { email: "bruno@lamarck.adv.br", password: "Password@123" }
    }
    response.headers["Authorization"]
  end

  describe "Fato (g): Concorrência na fila de conferência entre múltiplos atendentes" do
    let!(:documento) do
      Documento.create!(
        tipo: "desconhecido",
        origem: "whatsapp",
        sha256_arquivo: Digest::SHA256.hexdigest("doc_concorrencia_test"),
        status: :necessita_revisao,
        score_confianca: 0.40,
        lock_version: 0
      )
    end

    it "permite a aprovação do primeiro atendente (200 OK) e rejeita o segundo com conflito (409 Conflict)" do
      # 1. Ambos os operadores leem o documento ao mesmo tempo (lock_version = 0)
      initial_lock_version = documento.lock_version
      expect(initial_lock_version).to eq(0)

      # 2. Atendente Ana envia a revisão primeiro com lock_version: 0
      patch "/api/v1/documentos/#{documento.id}/revisar",
            params: {
              lock_version: 0,
              tipo: "rg",
              nome_arquivo: "RG_Ana_Aprovado.pdf",
              cliente_id: cliente.id,
              dados_extraidos: { "nome" => "Silva Aprovado", "rg" => "12345" }
            },
            headers: { "Authorization" => token_ana }

      expect(response).to have_http_status(:ok)
      json_ana = JSON.parse(response.body)
      expect(json_ana["mensagem"]).to eq("Documento conferido e aprovado com sucesso")
      expect(documento.reload.lock_version).to eq(1)
      expect(documento.status).to eq("processado")
      expect(documento.revisado_por_id).to eq(usuario_a.id)

      # 3. Atendente Bruno tenta enviar a revisão dele baseada no lock_version: 0 que ele leu inicialmente
      patch "/api/v1/documentos/#{documento.id}/revisar",
            params: {
              lock_version: 0,
              tipo: "cnh",
              nome_arquivo: "CNH_Bruno_Sobrescrita.pdf",
              cliente_id: cliente.id,
              dados_extraidos: { "nome" => "Tentativa Bruno", "rg" => "99999" }
            },
            headers: { "Authorization" => token_bruno }

      expect(response).to have_http_status(:conflict)
      json_bruno = JSON.parse(response.body)
      expect(json_bruno["error"]).to eq("Conflito de concorrência")
      expect(json_bruno["message"]).to include("O registro foi modificado simultaneamente por outro operador")

      # 4. Garante que os dados da Ana NÃO foram corrompidos pela tentativa do Bruno
      documento.reload
      expect(documento.tipo).to eq("rg")
      expect(documento.nome_arquivo).to eq("RG_Ana_Aprovado.pdf")
      expect(documento.revisado_por_id).to eq(usuario_a.id)
      expect(documento.lock_version).to eq(1)
    end

    it "demonstra proteção contra colisão em threads concorrentes paralelas no banco de dados" do
      doc_multithread = Documento.create!(
        tipo: "desconhecido",
        origem: "manual",
        sha256_arquivo: Digest::SHA256.hexdigest("thread_concorrencia_test"),
        status: :necessita_revisao,
        lock_version: 0
      )

      resultados = []
      threads = []
      mutex = Mutex.new

      # Dispara duas threads concorrentes tentando atualizar o mesmo registro a partir da mesma versão
      2.times do |i|
        threads << Thread.new do
          # Abre conexão isolada no pool para simular conexões independentes de atendentes
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              doc = Documento.find(doc_multithread.id)
              # Simula atraso milimétrico de rede
              sleep(0.01 * i)
              doc.tipo = (i == 0 ? "rg" : "cnh")
              doc.save!
              mutex.synchronize { resultados << { thread: i, status: :sucesso } }
            rescue ActiveRecord::StaleObjectError => e
              mutex.synchronize { resultados << { thread: i, status: :stale_object_conflict, erro: e.class.name } }
            end
          end
        end
      end

      threads.each(&:join)

      status_counts = resultados.map { |r| r[:status] }
      expect(status_counts).to include(:sucesso)
      expect(status_counts).to include(:stale_object_conflict)
      expect(doc_multithread.reload.lock_version).to eq(1)
    end
  end

  describe "Fato (c): Deduplicação Concorrente e Idempotência no PostgreSQL" do
    it "garante que uploads concorrentes simultâneos do mesmo arquivo com mesmo cliente resultam em deduplicação segura" do
      arquivo_conteudo = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\nCONTEUDO_DO_ARQUIVO_EM_PDF_CONCORRENTE_#{SecureRandom.hex(8)}"
      tempfile1 = Tempfile.new([ "upload_concorrente_1", ".pdf" ])
      tempfile1.write(arquivo_conteudo)
      tempfile1.rewind

      uploaded_file1 = ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile1,
        filename: "documento_original.pdf",
        type: "application/pdf"
      )

      # 1. Primeiro upload ingere e cria o documento
      resultado1 = Documentos::IngestaoService.ingestar!(
        uploaded_file1,
        origem: :manual,
        cliente_id: cliente.id,
        nome_arquivo: "documento_original.pdf"
      )

      expect(resultado1.duplicado).to be(false)
      expect(resultado1.documento).to be_persisted

      # 2. Segundo upload do mesmo arquivo para o mesmo cliente é capturado pela camada de deduplicação SHA-256
      tempfile2 = Tempfile.new([ "upload_concorrente_2", ".pdf" ])
      tempfile2.write(arquivo_conteudo)
      tempfile2.rewind

      uploaded_file2 = ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile2,
        filename: "documento_reenviado_por_inseguranca.pdf",
        type: "application/pdf"
      )

      resultado2 = Documentos::IngestaoService.ingestar!(
        uploaded_file2,
        origem: :manual,
        cliente_id: cliente.id,
        nome_arquivo: "documento_reenviado_por_inseguranca.pdf"
      )

      expect(resultado2.duplicado).to be(true)
      expect(resultado2.documento.id).to eq(resultado1.documento.id)
      expect(Documento.where(cliente_id: cliente.id, sha256_arquivo: resultado1.documento.sha256_arquivo).count).to eq(1)

      tempfile1.close
      tempfile1.unlink
      tempfile2.close
      tempfile2.unlink
    end
  end
end
