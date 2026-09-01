class AddOrdemToConfiguracoesProvedorIa < ActiveRecord::Migration[8.1]
  def change
    add_column :configuracoes_provedor_ia, :ordem, :integer
    add_index :configuracoes_provedor_ia, :ordem, unique: true, where: "ativo = true", name: "idx_config_provedor_ia_ordem_ativo_unique"
  end
end
