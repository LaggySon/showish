defmodule Showish.Accounts.Scope do
  @moduledoc """
  The caller a request is being served for.

  Contexts take a scope rather than a bare user id, so that "whose shows?" is
  answered in one place and cannot be forgotten at a call site. A `nil` scope
  means nobody is logged in — which is the normal state for overlays, since
  they are loaded by broadcast software that cannot sign in.

  See the [Phoenix scopes guide](https://hexdocs.pm/phoenix/scopes.html).
  """

  alias Showish.Accounts.Scope
  alias Showish.Accounts.User

  defstruct user: nil

  @type t :: %__MODULE__{user: User.t() | nil}

  @doc "Wraps a user in a scope. `nil` in, `nil` out."
  def for_user(%User{} = user), do: %Scope{user: user}
  def for_user(nil), do: nil
end
