defmodule Showish.Repo.Migrations.CreateThemes do
  use Ecto.Migration

  def change do
    create table(:themes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :base, :string, null: false, default: "broadcast"
      add :tokens, :map, null: false, default: %{}
      add :fonts, :map, null: false, default: %{}
      add :css, :text, null: false, default: ""
      add :share_code, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:themes, [:user_id])
    create unique_index(:themes, [:user_id, :name])
    create unique_index(:themes, [:share_code])

    # A show drawn in a theme. Deleting the theme drops the show back to its
    # built-in look rather than taking the show with it.
    alter table(:shows) do
      add :theme_id, references(:themes, on_delete: :nilify_all)
    end

    create index(:shows, [:theme_id])
  end
end
