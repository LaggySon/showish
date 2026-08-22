defmodule Showish.Repo.Migrations.AddPitchCountsToLineupSpots do
  use Ecto.Migration

  def change do
    alter table(:baseball_lineup_spots) do
      add :pitch_count, :integer, null: false, default: 0
    end

    execute(
      """
      UPDATE baseball_lineup_spots AS spot
      SET pitch_count = CASE
        WHEN game.away_pitcher_id = spot.player_id THEN game.away_pitch_count
        WHEN game.home_pitcher_id = spot.player_id THEN game.home_pitch_count
        ELSE 0
      END
      FROM baseball_games AS game
      WHERE spot.game_id = game.id
        AND spot.player_id IN (game.away_pitcher_id, game.home_pitcher_id)
      """,
      "UPDATE baseball_lineup_spots SET pitch_count = 0"
    )
  end
end
