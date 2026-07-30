defmodule Showish.Broadcasts.Talent do
  @moduledoc """
  A person on the broadcast: caster, host, observer, producer, and so on.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "talents" do
    field :position, :integer, default: 0
    field :role, :string, default: "Caster"
    field :name, :string, default: ""
    field :pronouns, :string, default: ""
    field :social, :string, default: ""
    field :avatar_url, :string, default: ""
    # Who is actually on a camera. Roles are free text, so the crew list cannot
    # be filtered by role — a producer or observer is on the crew but not on the
    # desk, and only the operator knows which is which.
    field :on_cam, :boolean, default: false

    belongs_to :show, Showish.Broadcasts.Show

    timestamps(type: :utc_datetime)
  end

  @castable ~w(position role name pronouns social avatar_url on_cam)a

  def changeset(talent, attrs) do
    cast(talent, attrs, @castable)
  end
end
