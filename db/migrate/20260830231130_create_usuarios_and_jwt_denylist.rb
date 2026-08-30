class CreateUsuariosAndJwtDenylist < ActiveRecord::Migration[8.1]
  def change
    create_table :usuarios, id: :uuid do |t|
      t.string :nome, null: false
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps null: false
    end

    add_index :usuarios, :email, unique: true
    add_index :usuarios, :reset_password_token, unique: true

    create_table :jwt_denylists, id: :uuid do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false
    end
    add_index :jwt_denylists, :jti, unique: true
  end
end
