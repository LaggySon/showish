defmodule Mix.Tasks.Showish.ClaimShows do
  @shortdoc "Gives every ownerless show to an existing account"

  @moduledoc """
  Assigns shows that pre-date user accounts to one account.

      $ mix showish.claim_shows operator@example.com

  Shows created before Showish had accounts have no owner, so they show up on
  nobody's shelf. Their overlay URLs keep working throughout — this only decides
  who is allowed to change them.

  In a release, where Mix is not available, call the same thing directly:

      bin/showish eval 'Showish.Release.claim_shows("operator@example.com")'
  """

  use Mix.Task

  alias Showish.Accounts
  alias Showish.Accounts.Scope
  alias Showish.Broadcasts

  @requirements ["app.start"]

  @impl Mix.Task
  def run([email]) do
    case Accounts.get_user_by_email(email) do
      nil ->
        Mix.raise("no account with the email #{inspect(email)} — register one first")

      user ->
        count = Broadcasts.claim_unowned_shows(Scope.for_user(user))
        Mix.shell().info("Moved #{count} show(s) to #{user.email}.")
    end
  end

  def run(_args) do
    Mix.raise("usage: mix showish.claim_shows EMAIL")
  end
end
