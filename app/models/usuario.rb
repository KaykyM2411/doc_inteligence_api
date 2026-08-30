# frozen_string_literal: true

class Usuario < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  has_many :documentos_revisados,
           class_name: "Documento",
           foreign_key: "revisado_por_id",
           dependent: :nullify,
           inverse_of: :revisado_por

  validates :nome, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
end
