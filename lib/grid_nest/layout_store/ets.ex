defmodule GridNest.LayoutStore.Ets do
  @moduledoc """
  In-memory `GridNest.LayoutStore` backed by a protected ETS table owned
  by a long-lived `GenServer`.

  This adapter is a supervised process. The host application must add
  it to its own supervision tree — for example, in `application.ex`:

      children = [
        # ... your other children
        GridNest.LayoutStore.Ets
      ]

  GridNest itself does not auto-start this process; pulling runtime
  children into the host's supervision tree keeps lifecycle and
  shutdown under the host's control and avoids the "library reads
  Application env" anti-pattern.

  Layouts are stored keyed by `{user_scope, page_key, browser_hash}`
  alongside a monotonic `updated_at` timestamp so that
  `load_any_browser/1` can surface the most-recently-touched layout for
  a given user+page.

  Writes happen through the owner process (for serialisation), reads go
  directly against the ETS table for concurrency.
  """

  @behaviour GridNest.LayoutStore

  use GenServer

  alias GridNest.Layout.Key

  @table __MODULE__

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Clears every stored layout. Intended for tests.
  """
  @spec reset!() :: :ok
  def reset! do
    GenServer.call(__MODULE__, :reset)
  end

  @impl GridNest.LayoutStore
  def load(%Key{browser_hash: :any}) do
    {:error, :wildcard_key}
  end

  def load(%Key{} = key) do
    case :ets.lookup(@table, record_key(key)) do
      [{_, layout, _updated_at}] -> {:ok, layout}
      [] -> :miss
    end
  end

  @impl GridNest.LayoutStore
  def load_any_browser(%Key{user_scope: scope, page_key: page}) do
    match = [
      {
        {{:"$1", :"$2", :"$3"}, :"$4", :"$5"},
        [{:andalso, {:"=:=", :"$1", {:const, scope}}, {:"=:=", :"$2", {:const, page}}}],
        [{{:"$3", :"$4", :"$5"}}]
      }
    ]

    case :ets.select(@table, match) do
      [] ->
        :miss

      rows ->
        {_hash, layout, _ts} = Enum.max_by(rows, fn {_h, _l, ts} -> ts end)
        {:ok, layout}
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
  def init(_opts) do
    table =
      :ets.new(@table, [
        :named_table,
        :set,
        :protected,
        read_concurrency: true
      ])

    {:ok, %{table: table, counter: 0}}
  end

  @impl GenServer
  def handle_call({:save, %Key{} = key, layout}, _from, state) do
    counter = state.counter + 1
    true = :ets.insert(@table, {record_key(key), layout, counter})
    {:reply, :ok, %{state | counter: counter}}
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    true = :ets.delete_all_objects(@table)
    {:reply, :ok, %{state | counter: 0}}
  end

  defp record_key(%Key{user_scope: scope, page_key: page, browser_hash: hash}) do
    {scope, page, hash}
  end
end
