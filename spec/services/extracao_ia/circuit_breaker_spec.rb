require "spec_helper"
require "faraday"
require_relative "../../../app/services/extracao_ia/circuit_breaker"

RSpec.describe ExtracaoIa::CircuitBreaker do
  let(:mock_redis) { double("Redis") }
  let(:breaker) { described_class.new("test_provider", redis: mock_redis) }

  before do
    allow(mock_redis).to receive(:get).and_return(nil)
    allow(mock_redis).to receive(:set)
    allow(mock_redis).to receive(:incr).and_return(1)
    allow(mock_redis).to receive(:expire)
    allow(mock_redis).to receive(:del)
    allow(mock_redis).to receive(:exists?).and_return(false)
  end

  describe "#state" do
    it "returns :closed by default when state is not open" do
      expect(breaker.state).to eq(:closed)
      expect(breaker.closed?).to be true
      expect(breaker.open?).to be false
    end

    it "returns :open when redis state is open and cooldown is active" do
      allow(mock_redis).to receive(:get).with("circuit_breaker:extracao_ia:test_provider:state").and_return("open")
      allow(mock_redis).to receive(:exists?).with("circuit_breaker:extracao_ia:test_provider:failures").and_return(true)

      expect(breaker.state).to eq(:open)
      expect(breaker.open?).to be true
    end

    it "returns :half_open when redis state is open but cooldown has expired" do
      allow(mock_redis).to receive(:get).with("circuit_breaker:extracao_ia:test_provider:state").and_return("open")
      allow(mock_redis).to receive(:exists?).with("circuit_breaker:extracao_ia:test_provider:failures").and_return(false)

      expect(breaker.state).to eq(:half_open)
      expect(breaker.half_open?).to be true
    end
  end

  describe "#call" do
    it "yields the block and records success when closed" do
      executed = false
      result = breaker.call do
        executed = true
        "success_result"
      end

      expect(executed).to be true
      expect(result).to eq("success_result")
      expect(mock_redis).to have_received(:del).with("circuit_breaker:extracao_ia:test_provider:state")
    end

    it "raises CircuitOpenError without executing the block when circuit is open" do
      allow(mock_redis).to receive(:get).with("circuit_breaker:extracao_ia:test_provider:state").and_return("open")
      allow(mock_redis).to receive(:exists?).with("circuit_breaker:extracao_ia:test_provider:failures").and_return(true)

      executed = false
      expect do
        breaker.call { executed = true }
      end.to raise_error(ExtracaoIa::CircuitOpenError, /Circuit Breaker: OPEN/)

      expect(executed).to be false
    end

    it "records failure and trips circuit to open when failure threshold is reached" do
      allow(mock_redis).to receive(:incr).and_return(5)

      expect do
        breaker.call { raise Faraday::ConnectionFailed, "Connection refused" }
      end.to raise_error(Faraday::ConnectionFailed)

      expect(mock_redis).to have_received(:set).with(
        "circuit_breaker:extracao_ia:test_provider:state",
        "open",
        ex: 120
      )
    end
  end
end
