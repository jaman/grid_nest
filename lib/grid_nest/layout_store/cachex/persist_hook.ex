defmodule GridNest.LayoutStore.Cachex.PersistHook do
  @moduledoc """
  Cachex post-write hook that persists the cache to disk after mutations.
  """

  use Cachex.Hook

  @impl Cachex.Hook
  def actions, do: [:put]

  @impl Cachex.Hook
  def async?, do: false

  @impl Cachex.Hook
  def type, do: :post

  @impl GenServer
  def init({cache_name, disk_path}) do
    {:ok, %{cache_name: cache_name, disk_path: disk_path}}
  end

  @impl Cachex.Hook
  def handle_notify(_action, _result, state) do
    disk_path = state.disk_path
    disk_path |> Path.dirname() |> File.mkdir_p!()
    Cachex.save(state.cache_name, disk_path)
    {:ok, state}
  end
end
