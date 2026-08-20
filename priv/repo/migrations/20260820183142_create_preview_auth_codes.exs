defmodule Showish.Repo.Migrations.CreatePreviewAuthCodes do
  use Ecto.Migration

  def change do
    create table(:preview_auth_codes) do
      add :token, :binary, null: false
      add :google_id, :string, null: false
      add :email, :string, null: false
      add :name, :string, null: false, default: ""
      add :avatar_url, :string, null: false, default: ""
      add :return_to, :string, null: false
      add :nonce, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:preview_auth_codes, [:token])
    create index(:preview_auth_codes, [:expires_at])
  end
end
