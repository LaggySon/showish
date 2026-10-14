defmodule Showish.Repo.Migrations.CreateBaseballGameModel do
  use Ecto.Migration

  def change do
    create table(:baseball_games) do
      add :show_id, references(:shows, on_delete: :delete_all), null: false
      add :inning, :integer, null: false, default: 1
      add :half, :string, null: false, default: "top"
      add :balls, :integer, null: false, default: 0
      add :strikes, :integer, null: false, default: 0
      add :outs, :integer, null: false, default: 0
      add :first_occupied, :boolean, null: false, default: false
      add :second_occupied, :boolean, null: false, default: false
      add :third_occupied, :boolean, null: false, default: false
      add :away_batter_order, :integer, null: false, default: 1
      add :home_batter_order, :integer, null: false, default: 1
      add :away_pitch_count, :integer, null: false, default: 0
      add :home_pitch_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:baseball_games, [:show_id])

    create table(:baseball_players) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :jersey_number, :string, null: false, default: ""
      add :bats, :string, null: false, default: ""
      add :throws, :string, null: false, default: ""
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:baseball_players, [:team_id])
    create unique_index(:baseball_players, [:team_id, :name])

    alter table(:baseball_games) do
      add :away_pitcher_id, references(:baseball_players, on_delete: :nilify_all)
      add :home_pitcher_id, references(:baseball_players, on_delete: :nilify_all)
      add :first_runner_id, references(:baseball_players, on_delete: :nilify_all)
      add :second_runner_id, references(:baseball_players, on_delete: :nilify_all)
      add :third_runner_id, references(:baseball_players, on_delete: :nilify_all)
      add :spotlight_player_id, references(:baseball_players, on_delete: :nilify_all)
      add :comparison_left_player_id, references(:baseball_players, on_delete: :nilify_all)
      add :comparison_right_player_id, references(:baseball_players, on_delete: :nilify_all)
    end

    create table(:baseball_lineup_spots) do
      add :game_id, references(:baseball_games, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :player_id, references(:baseball_players, on_delete: :delete_all), null: false
      add :batting_order, :integer
      add :field_position, :string, null: false, default: ""
      add :starter, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:baseball_lineup_spots, [:game_id, :team_id])
    create unique_index(:baseball_lineup_spots, [:game_id, :player_id])
    create unique_index(:baseball_lineup_spots, [:game_id, :team_id, :batting_order])

    create table(:baseball_game_events) do
      add :game_id, references(:baseball_games, on_delete: :delete_all), null: false
      add :sequence, :integer, null: false
      add :action, :string, null: false
      add :params, :map, null: false, default: %{}
      add :state_before, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:baseball_game_events, [:game_id, :sequence])

    create table(:baseball_plate_appearances) do
      add :game_id, references(:baseball_games, on_delete: :delete_all), null: false
      add :event_id, references(:baseball_game_events, on_delete: :delete_all), null: false
      add :batter_id, references(:baseball_players, on_delete: :nilify_all)
      add :pitcher_id, references(:baseball_players, on_delete: :nilify_all)
      add :batting_team_id, references(:teams, on_delete: :delete_all), null: false
      add :sequence, :integer, null: false
      add :inning, :integer, null: false
      add :half, :string, null: false
      add :result, :string, null: false
      add :at_bat, :boolean, null: false, default: true
      add :hit_value, :integer, null: false, default: 0
      add :rbi, :integer, null: false, default: 0
      add :runs_scored, :integer, null: false, default: 0
      add :outs_recorded, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:baseball_plate_appearances, [:game_id, :sequence])
    create index(:baseball_plate_appearances, [:batter_id])

    create table(:baseball_pitches) do
      add :game_id, references(:baseball_games, on_delete: :delete_all), null: false
      add :event_id, references(:baseball_game_events, on_delete: :delete_all), null: false
      add :batter_id, references(:baseball_players, on_delete: :nilify_all)
      add :pitcher_id, references(:baseball_players, on_delete: :nilify_all)
      add :sequence, :integer, null: false
      add :result, :string, null: false
      add :balls_before, :integer, null: false
      add :strikes_before, :integer, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:baseball_pitches, [:game_id, :sequence])
    create index(:baseball_pitches, [:pitcher_id])

    create table(:baseball_bullpen_entries) do
      add :game_id, references(:baseball_games, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :player_id, references(:baseball_players, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0
      add :status, :string, null: false, default: "Available"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:baseball_bullpen_entries, [:game_id, :team_id])
    create unique_index(:baseball_bullpen_entries, [:game_id, :player_id])
  end
end
