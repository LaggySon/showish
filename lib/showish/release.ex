defmodule Showish.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :showish

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Gives every show that pre-dates user accounts to one existing account.

  The release-side twin of `mix showish.claim_shows`:

      bin/showish eval 'Showish.Release.claim_shows("operator@example.com")'
  """
  def claim_shows(email) when is_binary(email) do
    load_app()
    {:ok, _apps} = Application.ensure_all_started(@app)

    case Showish.Accounts.get_user_by_email(email) do
      nil ->
        raise "no account with the email #{inspect(email)} — register one first"

      user ->
        count = Showish.Broadcasts.claim_unowned_shows(Showish.Accounts.Scope.for_user(user))
        IO.puts("Moved #{count} show(s) to #{user.email}.")
        count
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
