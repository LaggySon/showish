defmodule Showish.Repo.Migrations.AddSportToShows do
  use Ecto.Migration

  def change do
    alter table(:shows) do
      add :sport, :string, null: false, default: "esports"
      add :sport_state, :map, null: false, default: %{}
    end
  end
end
