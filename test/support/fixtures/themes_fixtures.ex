defmodule Showish.ThemesFixtures do
  @moduledoc "Test helpers for creating themes."

  import Showish.AccountsFixtures

  alias Showish.Accounts.Scope
  alias Showish.Themes

  @doc """
  Creates a theme, owned by `scope` or by a throwaway account, with whatever the
  caller overrides.
  """
  def theme_fixture(scope_or_attrs \\ %{})

  def theme_fixture(%Scope{} = scope), do: theme_fixture(scope, %{})
  def theme_fixture(attrs) when is_map(attrs), do: theme_fixture(user_scope_fixture(), attrs)

  def theme_fixture(%Scope{} = scope, attrs) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

    {:ok, theme} =
      %{"name" => "Theme #{System.unique_integer([:positive])}", "base" => "broadcast"}
      |> Map.merge(attrs)
      |> then(&Themes.create_theme(scope, &1))

    theme
  end

  @doc "The smallest bytes that pass for a WOFF2 file, base64-encoded."
  def woff2_data, do: Base.encode64("wOF2" <> :binary.copy(<<0>>, 64))
end
