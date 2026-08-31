# frozen_string_literal: true

require "rails_helper"

RSpec.describe "IngestaoEmail Ports & Adapters", type: :service do
  describe IngestaoEmail::Factory do
    it "returns SendgridAdapter for sendgrid" do
      adapter = described_class.for_provider("sendgrid")
      expect(adapter).to be_a(IngestaoEmail::Adapters::SendgridAdapter)
      expect(adapter.provider_name).to eq("sendgrid")
    end

    it "returns PostmarkAdapter for postmark" do
      adapter = described_class.for_provider("postmark")
      expect(adapter).to be_a(IngestaoEmail::Adapters::PostmarkAdapter)
      expect(adapter.provider_name).to eq("postmark")
    end

    it "returns MockEmailAdapter for mock" do
      adapter = described_class.for_provider("mock")
      expect(adapter).to be_a(IngestaoEmail::Adapters::MockEmailAdapter)
    end
  end

  describe IngestaoEmail::Adapters::SendgridAdapter do
    subject(:adapter) { described_class.new }

    it "parses SendGrid Inbound Parse multipart payload with attachment-info and attachment1" do
      fake_file = Rack::Test::UploadedFile.new(
        StringIO.new("%PDF-1.4 sendgrid document binary stream"),
        "application/pdf",
        original_filename: "relatorio_financeiro.pdf"
      )

      payload = {
        "headers" => "From: Maria Silva <maria@example.com>\nTo: docs@lamarck.adv.br\nMessage-ID: <msg_sendgrid_98765@mail.example.com>\nSubject: Envio de Documentos",
        "envelope" => { "to" => [ "docs@lamarck.adv.br" ], "from" => "maria@example.com" }.to_json,
        "from" => "Maria Silva <maria@example.com>",
        "to" => "docs@lamarck.adv.br",
        "subject" => "Envio de Documentos",
        "attachments" => "1",
        "attachment-info" => {
          "attachment1" => {
            "filename" => "relatorio_financeiro.pdf",
            "type" => "application/pdf",
            "content-id" => "ii_12345"
          }
        }.to_json,
        "attachment1" => fake_file
      }

      email_msg = adapter.parse_payload(payload)

      expect(email_msg.provider_name).to eq("sendgrid")
      expect(email_msg.reference_id).to eq("msg_sendgrid_98765@mail.example.com")
      expect(email_msg.sender_email).to include("maria@example.com")
      expect(email_msg.recipient_email).to eq("docs@lamarck.adv.br")
      expect(email_msg.subject).to eq("Envio de Documentos")
      expect(email_msg).to have_attachments
      expect(email_msg.attachments.first.filename).to eq("relatorio_financeiro.pdf")
      expect(email_msg.attachments.first.content_type).to eq("application/pdf")
      expect(email_msg.attachments.first.bytes).to start_with("%PDF-1.4")
    end
  end

  describe IngestaoEmail::Adapters::PostmarkAdapter do
    subject(:adapter) { described_class.new }

    it "parses Postmark JSON inbound payload and decodes Base64 attachments" do
      base64_pdf = Base64.encode64("%PDF-1.4 postmark document content")

      payload = {
        "MessageID" => "73e6d360-c983-4a29-9c7f-820737425724",
        "From" => "joao@example.com",
        "FromFull" => { "Email" => "joao@example.com", "Name" => "João Silva" },
        "To" => "inbound@lamarck.adv.br",
        "Subject" => "Comprovante de Endereço",
        "TextBody" => "Segue em anexo o comprovante.",
        "Attachments" => [
          {
            "Name" => "comprovante_residencia.pdf",
            "ContentType" => "application/pdf",
            "Content" => base64_pdf,
            "ContentLength" => base64_pdf.bytesize
          }
        ]
      }

      email_msg = adapter.parse_payload(payload)

      expect(email_msg.provider_name).to eq("postmark")
      expect(email_msg.reference_id).to eq("73e6d360-c983-4a29-9c7f-820737425724")
      expect(email_msg.sender_email).to eq("joao@example.com")
      expect(email_msg.subject).to eq("Comprovante de Endereço")
      expect(email_msg).to have_attachments
      expect(email_msg.attachments.first.filename).to eq("comprovante_residencia.pdf")
      expect(email_msg.attachments.first.bytes).to start_with("%PDF-1.4")
    end
  end

  describe IngestaoEmail::Adapters::MockEmailAdapter do
    subject(:adapter) { described_class.new }

    it "returns deterministic email message for testing" do
      result = adapter.parse_payload({})
      expect(result.provider_name).to eq("mock")
      expect(result.reference_id).to be_present
      expect(result.attachments).not_to be_empty
    end
  end
end
