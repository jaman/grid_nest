defmodule GridNest.LayoutStore.Dets do
  @moduledoc """
  Disk-backed `GridNest.LayoutStore` built on top of Erlang's `:dets`.

  A single DETS file owned by a named GenServer. No external dependencies —
  `:dets` ships with Erlang/OTP.

  ## Options

    * `:file` — path to the DETS file. Defaults to
      `Path.join(:code.priv_dir(:grid_nest), "grid_nest_layouts.dets")`.
    * `:name` — the process name. Defaults to `#{inspect(__MODULE__)}`.

  Under the hood, each record is `{{user_scope, page_key, browser_hash},
  layout, monotonic_counter}`. The counter gives `load_any_browser/1` a
  deterministic "most recent" query without touching wall-clock time.
  """

  @behaviour GridNest.LayoutStore

  use GenServer

  alias GridNest.Layout.Key

  @table __MODULE__

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GridNest.LayoutStore
  def load(%Key{browser_hash: :any}), do: {:error, :wildcard_key}

  def load(%Key{} = key) do
    case GenServer.call(__MODULE__, :get_table) do
      {:ok, table} ->
        case :dets.lookup(table, record_key(key)) do
          [{_, layout, _counter}] -> {:ok, layout}
          [] -> :miss
        end

      other ->
        other
    end
  end

  @impl GridNest.LayoutStore
  def load_any_browser(%Key{user_scope: scope, page_key: page}) do
    case GenServer.call(__MODULE__, :get_table) do
      {:ok, table} -> most_recent_for(table, scope, page)
      other -> other
    end
  end

  @impl GridNest.LayoutStore
  def save(%Key{browser_hash: :any}, _layout), do: {:error, :wildcard_key}

  def save(%Key{} = key, layout) when is_list(layout) do
    GenServer.call(__MODULE__, {:save, key, layout})
  end

  @impl GridNest.LayoutStore
  def default(_page_key), do: []

  @impl GenServer
  def init(opts) do
    file = Keyword.get(opts, :file, default_file())
    file |> Path.dirname() |> File.mkdir_p!()
    file_charlist = String.to_charlist(file)

    {:ok, table} = :dets.open_file(@table, [{:file, file_charlist}, {:type, :set}])

    counter = next_counter(table)
    {:ok, %{file: file, table: table, counter: counter}}
  end

  @impl GenServer
  def handle_call(:get_table, _from, state) do
    {:reply, {:ok, state.table}, state}
  end

  def handle_call({:save, %Key{} = key, layout}, _from, state) do
    counter = state.counter + 1
    :ok = :dets.insert(state.table, {record_key(key), layout, counter})
    :ok = :dets.sync(state.table)
    {:reply, :ok, %{state | counter: counter}}
  end

  @impl GenServer
  def terminate(_reason, state) do
    _ = :dets.close(state.table)
    :ok
  end

  defp most_recent_for(table, scope, page) do
    rows =
      :dets.foldl(
        fn
          {{^scope, ^page, _hash}, layout, counter}, acc -> [{layout, counter} | acc]
          _, acc -> acc
        end,
        [],
        table
      )

    case rows do
      [] ->
        :miss

      _ ->
        {layout, _counter} = Enum.max_by(rows, fn {_layout, counter} -> counter end)
        {:ok, layout}
    end
  end

  defp next_counter(table) do
    :dets.foldl(
      fn
        {_key, _layout, counter}, acc when is_integer(counter) -> max(counter, acc)
        _, acc -> acc
      end,
      0,
      table
    )
  end

  defp record_key(%Key{user_scope: scope, page_key: page, browser_hash: hash}) do
    {scope, page, hash}
  end

  defp default_file do
    :grid_nest
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("grid_nest_layouts.dets")
  end
end
