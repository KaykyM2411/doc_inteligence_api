# frozen_string_literal: true

class CriarUsuarioAdministrador < ActiveRecord::Migration[8.1]
  def up
    admin = Usuario.find_or_initialize_by(email: "admin@lamarck.adv.br")
    admin.nome = "Administrador Lamarck"
    admin.password = "Admin@123456"
    admin.password_confirmation = "Admin@123456"
    admin.save!

    puts "== CriarUsuarioAdministrador: Usuário admin criado (#{admin.email}) =="
  end

  def down
    Usuario.find_by(email: "admin@lamarck.adv.br")&.destroy
  end
end
