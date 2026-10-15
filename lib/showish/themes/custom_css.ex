defmodule Showish.Themes.CustomCSS do
  @moduledoc """
  The rules a theme's hand-written CSS has to follow.

  A theme can be shared, so its CSS is written by somebody other than the
  person whose overlays load it. CSS cannot run code, but it can make the
  browser fetch things, and a fetch that depends on a selector matching is
  enough to leak what is on the page, or to tell the author who is watching.
  So theme CSS may not reach the network at all: no `@import`, and no `url()`
  except an embedded `data:` URL. Fonts and images travel inside the theme.

  Two characters are refused outright. `<` has no use in a stylesheet and is
  how one would escape into the surrounding page. `\\` starts a CSS escape,
  which could spell any of the forbidden words in a way a plain text check
  would miss.
  """

  @max_bytes 200_000

  @data_url ~r/url\(\s*(?:"data:[^"]*"|'data:[^']*'|data:[^)\s"']*)\s*\)/i

  @forbidden [
    {~r/@import/i, "may not use @import; everything a theme needs travels inside it"},
    {~r/url\(/i, "may only use url() with an embedded data: URL"},
    {~r/image-set\(/i, "may not use image-set(); use url() with a data: URL"},
    {~r/(?<![\w-])src\(/i, "may not use src(); use url() with a data: URL"},
    {~r/expression\(|-moz-binding|behavior\s*:/i, "may not use script-like properties"}
  ]

  @doc "The largest custom stylesheet a theme may carry, in bytes."
  def max_bytes, do: @max_bytes

  @doc """
  Returns `:ok`, or `{:error, message}` naming the first rule `css` breaks.

      iex> Showish.Themes.CustomCSS.check(".overlay-panel { border-radius: 0; }")
      :ok

      iex> Showish.Themes.CustomCSS.check("body { background: url(https://example.com/x.png); }")
      {:error, "may only use url() with an embedded data: URL"}
  """
  def check(css) when is_binary(css) do
    cond do
      byte_size(css) > @max_bytes ->
        {:error, "is longer than #{div(@max_bytes, 1000)} KB"}

      String.contains?(css, "<") ->
        {:error, "may not contain <"}

      String.contains?(css, "\\") ->
        {:error, "may not contain a backslash; write characters out instead of escaping them"}

      true ->
        stripped = Regex.replace(@data_url, css, "")

        Enum.find_value(@forbidden, :ok, fn {pattern, message} ->
          if Regex.match?(pattern, stripped), do: {:error, message}
        end)
    end
  end

  def check(_css), do: {:error, "must be text"}
end
