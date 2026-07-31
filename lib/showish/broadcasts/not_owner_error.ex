defmodule Showish.Broadcasts.NotOwnerError do
  @moduledoc """
  Raised when a write is attempted against a show the scope does not own.

  Reaching this means a caller got a show from somewhere other than a scoped
  read, so it is a bug rather than something to rescue and render.
  """

  defexception [:slug]

  @impl true
  def exception(opts) do
    %__MODULE__{slug: opts[:slug]}
  end

  @impl true
  def message(%__MODULE__{slug: slug}) do
    "the show #{inspect(slug)} belongs to a different account"
  end
end
