defmodule GridNest.LayoutStore do
  @moduledoc """
  Behaviour implemented by server-side layout persistence adapters.

  An adapter is a plain module the host application passes as a prop on
  `GridNest.Board`. GridNest itself ships several adapters (`Noop`,
  `Ets`, …) and a `mix grid_nest.install` igniter task can scaffold an
  `Ash`-resource-backed adapter into a host app.

  The behaviour contract is intentionally narrow:

    * `load/1` — retrieve the stored layout for an exact key. Returns
      `:miss` when nothing is stored (not an error).
    * `load_any_browser/1` — look up the most-recently-updated layout for
      the same `{user_scope, page_key}` across *any* browser hash. Used
      by the `:most_recent` new-browser fallback strategy. Adapters may
      return `:miss` even when a record exists for another browser if
      they don't support the query.
    * `save/2` — persist a layout under an exact key.
    * `default/1` — fall-through layout for a page when nothing is stored
      and no default was supplied via props. Adapters that have no sense
      of a page-level default return `[]`.

  All callbacks must be safe to call from any process; adapters that
  keep state do so via GenServer/ETS/DETS/etc. under GridNest's own
  supervision tree.
  """

  alias GridNest.Layout
  alias GridNest.Layout.Key

  @type load_result :: {:ok, Layout.t()} | :miss | {:error, term()}
  @type save_result :: :ok | {:error, term()}

  @callback load(Key.t()) :: load_result()
  @callback load_any_browser(Key.t()) :: load_result()
  @callback save(Key.t(), Layout.t()) :: save_result()
  @callback default(Key.page_key()) :: Layout.t()

  @optional_callbacks [load_any_browser: 1, default: 1]

  @doc """
  Dispatches `load/1` against an adapter module.
  """
  @spec load(module(), Key.t()) :: load_result()
  def load(adapter, %Key{} = key), do: adapter.load(key)

  @doc """
  Dispatches `load_any_browser/1`. Adapters that don't implement the
  optional callback simply return `:miss`.
  """
  @spec load_any_browser(module(), Key.t()) :: load_result()
  def load_any_browser(adapter, %Key{} = key) do
    if function_exported?(adapter, :load_any_browser, 1) do
      adapter.load_any_browser(key)
    else
      :miss
    end
  end

  @doc """
  Dispatches `save/2`.
  """
  @spec save(module(), Key.t(), Layout.t()) :: save_result()
  def save(adapter, %Key{} = key, layout) when is_list(layout) do
    adapter.save(key, layout)
  end

  @doc """
  Dispatches `default/1` with a graceful fallback to an empty layout.
  """
  @spec default(module(), Key.page_key()) :: Layout.t()
  def default(adapter, page_key) when is_binary(page_key) do
    if function_exported?(adapter, :default, 1) do
      adapter.default(page_key)
    else
      []
    end
  end
end
