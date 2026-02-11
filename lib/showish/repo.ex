defmodule Showish.Repo do
  use Ecto.Repo,
    otp_app: :showish,
    adapter: Ecto.Adapters.Postgres
end
