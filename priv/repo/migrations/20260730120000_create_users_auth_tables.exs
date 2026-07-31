defmodule Showish.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    # citext gives us case-insensitive emails without having to remember to
    # downcase on every read.
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :email, :citext, null: false
      # Google's subject id. Null until the account's first sign-in, so an
      # account can be provisioned by email before its owner has ever logged in.
      add :google_id, :string
      add :name, :string, null: false, default: ""
      add :avatar_url, :string, null: false, default: ""

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:google_id])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
