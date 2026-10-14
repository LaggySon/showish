defmodule Showish.Accounts.Allowlist do
  @moduledoc """
  Which Google addresses this deployment will sign in.

  An empty list means everyone: a plain checkout, and the production
  deployment, take whoever Google vouches for. The dev deployment sets the list
  so that a second copy of the app, sitting on a public URL with a database
  nobody is watching, is not an open door.

  The check happens on every sign-in rather than only at account creation, so
  taking an address off the list locks that person out of their next sign-in
  instead of only stopping new arrivals.

  Addresses are compared trimmed and lowercased, because that is how people
  type them into an environment variable and not necessarily how Google returns
  them.

  ## Configuration

      config :showish, Showish.Accounts.Allowlist,
        emails: ["operator@example.com", "producer@example.com"]

  `config/runtime.exs` passes `ALLOWED_GOOGLE_EMAILS` straight through, so the
  same key also accepts the comma-separated form that variable is written in:

      ALLOWED_GOOGLE_EMAILS="operator@example.com, producer@example.com"

  """

  @doc """
  The addresses on the list, trimmed and lowercased.

  `[]` when there is no list, which is how `allows?/1` knows to let everyone
  through.
  """
  def emails do
    case Application.get_env(:showish, __MODULE__) do
      nil -> []
      config -> config |> Keyword.get(:emails) |> to_list()
    end
  end

  @doc "Whether this deployment restricts who may sign in."
  def enforced?, do: emails() != []

  @doc """
  Whether `email` may sign in.

  True for everyone when no list is configured.
  """
  def allows?(email) when is_binary(email) do
    case emails() do
      [] -> true
      emails -> normalize(email) in emails
    end
  end

  def allows?(_email), do: false

  # Accepts either the list form, for config files and tests, or the
  # comma-separated string an environment variable arrives as.
  defp to_list(nil), do: []
  defp to_list(value) when is_binary(value), do: value |> String.split(",") |> clean()
  defp to_list(value) when is_list(value), do: clean(value)

  defp clean(emails) do
    emails
    |> Enum.map(&normalize/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize(email), do: email |> String.trim() |> String.downcase()
end
