defmodule Showish.Repo.Migrations.AddNotationToBaseballPlateAppearances do
  use Ecto.Migration

  def change do
    alter table(:baseball_plate_appearances) do
      add :notation, :string, null: false, default: ""
    end
  end
end
