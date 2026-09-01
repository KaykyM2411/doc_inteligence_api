# frozen_string_literal: true

# ==============================================================================
# DOC Intelligence API — Seeds & Inicialização de Dados de Domínio
# ==============================================================================
#
# A população de dados estruturais da aplicação (Estados, Cidades, Usuário Admin
# inicial e Provedores de IA padrão) é gerenciada exclusivamente pela gem
# `data_migrate` através de migrations de dados versionadas em `db/data/`.
#
# Isso garante:
# 1. Idempotência estrita entre ambientes (development, test, production);
# 2. Rastreabilidade histórica de mutações de dados na esteira de deploy;
# 3. Separação clara entre migrations de schema (DDL) e migrations de dados (DML).
#
# Para aplicar as migrações de dados, execute:
#   $ bin/rails data:migrate
# ==============================================================================

puts ""
puts "=== DOC Intelligence — Diagnóstico de Dados ==="

estados_count = Estado.count rescue 0
cidades_count = Cidade.count rescue 0
usuarios_count = Usuario.count rescue 0
provedores_count = ConfiguracaoProvedorIa.count rescue 0

if estados_count.zero?
  puts "⚠️  Base de dados ainda não foi populada com os dados de domínio."
  puts "👉 Execute: bin/rails data:migrate"
else
  puts "✓ Estados carregados: #{estados_count}"
  puts "✓ Cidades carregadas: #{cidades_count}"
  puts "✓ Usuários cadastrados: #{usuarios_count}"
  puts "✓ Provedores de IA configurados: #{provedores_count}"
  puts "✓ Banco de dados pronto para operação!"
end

puts "================================================"
puts ""
