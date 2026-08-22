defmodule Showish.Broadcasts.TeamProfile do
  @moduledoc "A reusable, account-owned team identity for quickly setting up future shows."

  use Ecto.Schema
  import Ecto.Changeset

  schema "team_profiles" do
    field :name, :string
    field :short_name, :string, default: ""
    field :code, :string, default: ""
    field :logo_url, :string, default: ""
    field :record, :string, default: ""
    field :primary_color, :string, default: "#1f2937"
    field :secondary_color, :string, default: "#f8fafc"
    field :roster, :map, default: %{"players" => []}

    belongs_to :user, Showish.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end

  @identity_fields ~w(name short_name code logo_url record primary_color secondary_color)a
  @fields [:roster | @identity_fields]

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, @fields)
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> Showish.Colors.validate_hex(:primary_color)
    |> Showish.Colors.validate_hex(:secondary_color)
    |> unique_constraint([:user_id, :name])
  end

  def team_attrs(profile), do: profile |> Map.from_struct() |> Map.take(@identity_fields)
end
