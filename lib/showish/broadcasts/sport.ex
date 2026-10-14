defmodule Showish.Broadcasts.Sport do
  @moduledoc """
  The catalogue and state contract for sports supported by Showish.

  This follows the same extension shape as `Showish.Broadcasts.Preset`: one
  ordered list drives selects and validation, while a small handler module owns
  sport-specific state and operator actions. Sport state is stored as a map on
  the show, so adding another sport does not require another database migration.

  To add a sport:

    1. implement this module's callbacks in `Showish.Broadcasts.Sports.<Name>`;
    2. add that module to `@sports` below;
    3. add a control-panel clause in `ShowishWeb.SportControls` and, only when
       its geometry differs, a scorebug clause in the scorebug overlay.

  Shared scenes, team branding, talent, URLs, PubSub updates and JSON output are
  inherited automatically.
  """

  alias Showish.Broadcasts.Sports.Baseball
  alias Showish.Broadcasts.Sports.Esports

  @type state :: map()
  @type transition_result :: {:ok, state()} | {:error, atom()}

  @callback metadata() :: %{required(:key) => String.t(), required(:name) => String.t()}
  @callback default_state() :: state()
  @callback normalize_state(term()) :: state()
  @callback transition(state(), String.t(), map()) :: transition_result()

  @sports [Esports, Baseball]

  @doc "Every sport, in the order offered to an operator."
  def all, do: Enum.map(@sports, &metadata/1)

  @doc "The keys a show may be set to."
  def keys, do: Enum.map(all(), & &1.key)

  @doc "The sport new shows use."
  def default, do: hd(all()).key

  @doc "Looks a sport up by key, falling back to the default."
  def fetch(key) do
    Enum.find(all(), hd(all()), &(&1.key == key))
  end

  @doc "Name/key pairs for sport selects."
  def options, do: Enum.map(all(), &{&1.name, &1.key})

  @doc "Returns normalized state using the selected sport's rules."
  def normalize_state(key, state), do: key |> handler() |> apply(:normalize_state, [state])

  @doc "Applies a validated operator action to a sport's state."
  def transition(key, state, action, params \\ %{}) do
    key |> handler() |> apply(:transition, [state, action, params])
  end

  @doc "Returns fresh state for a sport."
  def default_state(key), do: key |> handler() |> apply(:default_state, [])

  defp metadata(module), do: module.metadata() |> Map.put(:handler, module)

  defp handler(key), do: fetch(key).handler
end
