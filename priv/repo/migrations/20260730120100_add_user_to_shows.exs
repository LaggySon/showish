defmodule Showish.Repo.Migrations.AddUserToShows do
  use Ecto.Migration

  def change do
    # Nullable on purpose: shows that pre-date accounts have no owner yet. They
    # stay invisible until someone claims them with `mix showish.claim_shows`.
    alter table(:shows) do
      add :user_id, references(:users, on_delete: :delete_all)
    end

    create index(:shows, [:user_id])
  end
end
