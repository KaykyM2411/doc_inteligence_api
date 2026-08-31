# frozen_string_literal: true

require "rails_helper"

RSpec.describe Documentos::ValidadorArquivo, type: :service do
  let(:pdf_bytes) { "%PDF-1.4 sample pdf binary data stream" }
  let(:jpeg_bytes) { "\xFF\xD8\xFF\xE0\x00\x10JFIF".b }
  let(:png_bytes) { "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR".b }
  let(:webp_bytes) { "RIFF\x00\x00\x00\x00WEBPVP8 ".b }
  let(:exe_malicioso) { "MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xFF\xFF".b }
  let(:texto_puro) { "Este é apenas um arquivo de texto comum" }

  describe ".detectar_mime_type" do
    it "detects PDF magic bytes" do
      expect(described_class.detectar_mime_type(pdf_bytes)).to eq("application/pdf")
    end

    it "detects JPEG magic bytes" do
      expect(described_class.detectar_mime_type(jpeg_bytes)).to eq("image/jpeg")
    end

    it "detects PNG magic bytes" do
      expect(described_class.detectar_mime_type(png_bytes)).to eq("image/png")
    end

    it "detects WebP magic bytes" do
      expect(described_class.detectar_mime_type(webp_bytes)).to eq("image/webp")
    end

    it "returns nil for malicious executables and unsupported files" do
      expect(described_class.detectar_mime_type(exe_malicioso)).to be_nil
      expect(described_class.detectar_mime_type(texto_puro)).to be_nil
    end
  end

  describe ".valido?" do
    it "returns true for allowed formats" do
      expect(described_class.valido?(pdf_bytes)).to be true
      expect(described_class.valido?(jpeg_bytes)).to be true
      expect(described_class.valido?(png_bytes)).to be true
      expect(described_class.valido?(webp_bytes)).to be true
    end

    it "returns false for invalid or malicious formats" do
      expect(described_class.valido?(exe_malicioso)).to be false
      expect(described_class.valido?(texto_puro)).to be false
    end
  end
end
