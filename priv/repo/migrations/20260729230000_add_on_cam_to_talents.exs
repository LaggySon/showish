defmodule Showish.Repo.Migrations.AddOnCamToTalents do
  use Ecto.Migration

  def change do
    alter table(:talents) do
      add :on_cam, :boolean, null: false, default: false
    end
  end
end
