defmodule Showish.Repo.Migrations.CreateBroadcasts do
  use Ecto.Migration

  def change do
    create table(:shows) do
      add :slug, :string, null: false
      add :title, :string, null: false, default: ""
      add :subtitle, :string, null: false, default: ""
      add :stage, :string, null: false, default: ""
      add :starts_at, :utc_datetime
      add :ticker, :text, null: false, default: ""
      add :status_left, :string, null: false, default: ""
      add :status_center, :string, null: false, default: ""
      add :status_right, :string, null: false, default: ""
      add :show_status_left, :boolean, null: false, default: false
      add :show_status_center, :boolean, null: false, default: true
      add :show_status_right, :boolean, null: false, default: false
      add :current_game, :integer, null: false, default: 1
      add :best_of, :integer, null: false, default: 5
      add :show_sides, :boolean, null: false, default: false
      add :swap_sides, :boolean, null: false, default: false
      add :break_message, :string, null: false, default: ""
      add :accent_color, :string, null: false, default: "#22d3ee"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shows, [:slug])

    create table(:teams) do
      add :show_id, references(:shows, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 1
      add :name, :string, null: false, default: ""
      add :short_name, :string, null: false, default: ""
      add :code, :string, null: false, default: ""
      add :logo_url, :string, null: false, default: ""
      add :record, :string, null: false, default: ""
      add :score, :integer, null: false, default: 0
      add :primary_color, :string, null: false, default: "#1f2937"
      add :secondary_color, :string, null: false, default: "#f8fafc"
      add :side, :string, null: false, default: ""

      timestamps(type: :utc_datetime)
    end

    create index(:teams, [:show_id])
    create unique_index(:teams, [:show_id, :position])

    create table(:games) do
      add :show_id, references(:shows, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0
      add :name, :string, null: false, default: ""
      add :mode, :string, null: false, default: ""
      add :image_url, :string, null: false, default: ""
      add :score_a, :integer, null: false, default: 0
      add :score_b, :integer, null: false, default: 0
      add :winner, :string, null: false, default: ""
      add :completed, :boolean, null: false, default: false
      add :info, :string, null: false, default: ""

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:show_id])

    create table(:talents) do
      add :show_id, references(:shows, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0
      add :role, :string, null: false, default: ""
      add :name, :string, null: false, default: ""
      add :pronouns, :string, null: false, default: ""
      add :social, :string, null: false, default: ""
      add :avatar_url, :string, null: false, default: ""

      timestamps(type: :utc_datetime)
    end

    create index(:talents, [:show_id])
  end
end
