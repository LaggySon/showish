defmodule ShowishWeb.ThemePreview do
  @moduledoc """
  Lets the theme editor show a theme on a real scene before any show uses it.

  The editor embeds the overlay URL of one of the owner's shows with a signed
  `theme_preview` parameter. Only the theme's owner can get one signed, so the
  parameter cannot be used to dress a stranger's overlay in somebody's theme;
  and it only changes the page it is on, never the show.
  """

  alias Showish.Themes.Theme

  @salt "theme preview"
  # Long enough to leave an editor tab open all day.
  @max_age 60 * 60 * 24

  @doc "A token naming `theme`, for the overlay URL's `theme_preview` parameter."
  def sign(%Theme{id: id}), do: Phoenix.Token.sign(ShowishWeb.Endpoint, @salt, id)

  @doc "The theme id a token names, or `nil` for a bad or expired one."
  def verify(token) when is_binary(token) do
    case Phoenix.Token.verify(ShowishWeb.Endpoint, @salt, token, max_age: @max_age) do
      {:ok, id} -> id
      {:error, _reason} -> nil
    end
  end

  def verify(_token), do: nil
end
