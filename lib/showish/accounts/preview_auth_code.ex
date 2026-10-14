defmodule Showish.Accounts.PreviewAuthCode do
  @moduledoc false

  use Ecto.Schema

  schema "preview_auth_codes" do
    field :token, :binary
    field :google_id, :string
    field :email, :string
    field :name, :string, default: ""
    field :avatar_url, :string, default: ""
    field :return_to, :string
    field :nonce, :string
    field :expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
