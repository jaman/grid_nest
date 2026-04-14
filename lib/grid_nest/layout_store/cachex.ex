defmodule GridNest.LayoutStore.Cachex do
  @cache_name :grid_nest_layouts
  @counter_key :__grid_nest_counter__

  @moduledoc """
  `GridNest.LayoutStore` adapter backed by [Cachex](https://hexdocs.pm/cachex).

  Cachex is an **optional** dependency of GridNest; this module is only
  usable in host applications that have added `:cachex` to their own deps.

  ## Options

    * `:name` — the Cachex cache name. Defaults to `#{inspect(@cache_name)}`.
    * `:disk_path` — when provided, the adapter persists the cache to disk
      after every write and restores from disk on startup. This is the path
      to the backup file (e.g. `"/var/data/grid_nest_layouts.cachex"`).
      When omitted, the adapter is purely in-memory.

  ## Supervision

  Add this module to your supervision tree:

      children = [
        {GridNest.LayoutStore.Cachex, disk_path: "/var/data/layouts.cachex"}
      ]

  Or for in-memory only:

      children = [
        GridNest.LayoutStore.Cachex
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

  @spec cache_name() :: atom()
  def cache_name, do: @cache_name

  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @cache_name)
    disk_path = Keyword.get(opts, :disk_path)

    hooks =
      case disk_path do
        nil ->
          []

        path when is_binary(path) ->
          import Cachex.Spec

          [
            hook(
              module: GridNest.LayoutStore.Cachex.PersistHook,
              args: {name, path}
            )
          ]
      end

    case Cachex.start_link(name: name, hooks: hooks) do
      {:ok, pid} ->
        maybe_restore(name, disk_path)
        {:ok, pid}

      other ->
        other
    end
  end

  def child_spec(opts) do
    name = Keyword.get(opts, :name, @cache_name)

    %{
      id: {__MODULE__, name},
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @impl GridNest.LayoutStore
  def load(%Key{browser_hash: :any}), do: {:error, :wildcard_key}

  def load(%Key{} = key), do: load(key, @cache_name)

  @spec load(Key.t(), atom()) :: GridNest.LayoutStore.load_result()
  def load(%Key{browser_hash: :any}, _cache), do: {:error, :wildcard_key}

  def load(%Key{} = key, cache) do
    case Cachex.get(cache, record_key(key)) do
      {:ok, nil} -> :miss
      {:ok, {layout, _counter}} -> {:ok, layout}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl GridNest.LayoutStore
  def load_any_browser(%Key{user_scope: scope, page_key: page}) do
    load_any_browser_from(@cache_name, scope, page)
  end

  @impl GridNest.LayoutStore
  def save(%Key{browser_hash: :any}, _layout), do: {:error, :wildcard_key}

  def save(%Key{} = key, layout) when is_list(layout) do
    save(key, layout, @cache_name)
  end

  @spec save(Key.t(), GridNest.Layout.t(), atom()) :: GridNest.LayoutStore.save_result()
  def save(%Key{browser_hash: :any}, _layout, _cache), do: {:error, :wildcard_key}

  def save(%Key{} = key, layout, cache) when is_list(layout) do
    counter = increment_counter(cache)
    Cachex.put(cache, record_key(key), {layout, counter})
    :ok
  end

  @impl GridNest.LayoutStore
  def default(_page_key), do: []

  defp load_any_browser_from(cache, scope, page) do
    case scan_entries(cache) do
      {:ok, entries} -> most_recent(entries, scope, page)
      {:error, reason} -> {:error, reason}
    end
  end

  defp scan_entries(cache) do
    with {:ok, keys} <- Cachex.keys(cache) do
      entries =
        keys
        |> Enum.reject(&(&1 == @counter_key))
        |> Enum.map(&fetch_entry(cache, &1))

      {:ok, entries}
    end
  end

  defp fetch_entry(cache, key) do
    case Cachex.get(cache, key) do
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

  defp increment_counter(cache) do
    case Cachex.get(cache, @counter_key) do
      {:ok, nil} ->
        Cachex.put(cache, @counter_key, 1)
        1

      {:ok, current} when is_integer(current) ->
        next = current + 1
        Cachex.put(cache, @counter_key, next)
        next
    end
  end

  defp record_key(%Key{user_scope: scope, page_key: page, browser_hash: hash}) do
    {scope, page, hash}
  end

  defp maybe_restore(_cache, nil), do: :ok

  defp maybe_restore(cache, disk_path) do
    if File.exists?(disk_path) do
      Cachex.restore(cache, disk_path)
    end

    :ok
  end
end
