defmodule GridNest.LayoutStore.Cachex do
  @moduledoc """
  `GridNest.LayoutStore` adapter backed by [Cachex](https://hexdocs.pm/cachex).

  Cachex is an **optional** dependency of GridNest; this module is only
  usable in host applications that have added `:cachex` to their own deps.

  The adapter defaults to a cache named `:grid_nest_layouts`. The host
  application is responsible for starting the cache under its own
  supervision tree (or via `Cachex.start_link/2`), which also means
  disk persistence via Cachex's `:disk_copies` / snapshot options can
  be configured at start-time by the host without touching GridNest.

      children = [
        {Cachex, name: GridNest.LayoutStore.Cachex.cache_name()}
      ]

  ## Most-recent tracking

  Records are stored as `{layout, counter}` where `counter` is a
  monotonically-increasing integer owned by a tiny `:counters` array
  held in the cache itself. This avoids wall-clock time and keeps
  `load_any_browser/1` deterministic in tests.
  """

  @behaviour GridNest.LayoutStore
  @compile {:no_warn_undefined, Cachex}

  alias GridNest.Layout.Key

  @cache_name :grid_nest_layouts
  @counter_key :__grid_nest_counter__

  @spec cache_name() :: atom()
  def cache_name, do: @cache_name

  @impl GridNest.LayoutStore
  def load(%Key{browser_hash: :any}), do: {:error, :wildcard_key}

  def load(%Key{} = key) do
    case Cachex.get(@cache_name, record_key(key)) do
      {:ok, nil} -> :miss
      {:ok, {layout, _counter}} -> {:ok, layout}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl GridNest.LayoutStore
  def load_any_browser(%Key{user_scope: scope, page_key: page}) do
    case scan_entries() do
      {:ok, entries} -> most_recent(entries, scope, page)
      {:error, reason} -> {:error, reason}
    end
  end

  @impl GridNest.LayoutStore
  def save(%Key{browser_hash: :any}, _layout), do: {:error, :wildcard_key}

  def save(%Key{} = key, layout) when is_list(layout) do
    counter = increment_counter()
    Cachex.put(@cache_name, record_key(key), {layout, counter})
    :ok
  end

  @impl GridNest.LayoutStore
  def default(_page_key), do: []

  defp scan_entries do
    with {:ok, keys} <- Cachex.keys(@cache_name) do
      entries =
        keys
        |> Enum.reject(&(&1 == @counter_key))
        |> Enum.map(&fetch_entry/1)

      {:ok, entries}
    end
  end

  defp fetch_entry(key) do
    case Cachex.get(@cache_name, key) do
      {:ok, value} -> {key, value}
      _ -> {key, nil}
    end
  end

  defp most_recent(entries, scope, page) do
    matches =
      for {{^scope, ^page, _hash}, {layout, counter}} <- entries do
        {layout, counter}
      end

    case matches do
      [] ->
        :miss

      _ ->
        {layout, _counter} = Enum.max_by(matches, fn {_layout, counter} -> counter end)
        {:ok, layout}
    end
  end

  defp increment_counter do
    case Cachex.get(@cache_name, @counter_key) do
      {:ok, nil} ->
        Cachex.put(@cache_name, @counter_key, 1)
        1

      {:ok, current} when is_integer(current) ->
        next = current + 1
        Cachex.put(@cache_name, @counter_key, next)
        next
    end
  end

  defp record_key(%Key{user_scope: scope, page_key: page, browser_hash: hash}) do
    {scope, page, hash}
  end
end
