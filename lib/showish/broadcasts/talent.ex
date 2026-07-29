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

    belongs_to :show, Showish.Broadcasts.Show

    timestamps(type: :utc_datetime)
  end

  @castable ~w(position role name pronouns social avatar_url)a

  def changeset(talent, attrs) do
    cast(talent, attrs, @castable)
  end
end
