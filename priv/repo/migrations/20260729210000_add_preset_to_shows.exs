defmodule Showish.Repo.Migrations.AddPresetToShows do
  use Ecto.Migration

  def change do
    alter table(:shows) do
      add :preset, :string, null: false, default: "broadcast"
    end
  end
end
