defmodule Showish.Repo.Migrations.CreateTeamProfiles do
  use Ecto.Migration

  def change do
    create table(:team_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :short_name, :string, null: false, default: ""
      add :code, :string, null: false, default: ""
      add :logo_url, :string, null: false, default: ""
      add :record, :string, null: false, default: ""
      add :primary_color, :string, null: false, default: "#1f2937"
      add :secondary_color, :string, null: false, default: "#f8fafc"
      add :roster, :map, null: false, default: %{"players" => []}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:team_profiles, [:user_id])
    create unique_index(:team_profiles, [:user_id, :name])
  end
end
