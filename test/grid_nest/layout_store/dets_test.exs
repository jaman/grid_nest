defmodule GridNest.LayoutStore.DetsTest do
  use GridNest.LayoutStoreCase,
    adapter: GridNest.LayoutStore.Dets,
    supports: [:any_browser]

  alias GridNest.Layout
  alias GridNest.Layout.Key
  alias GridNest.LayoutStore.Dets

  setup do
    dir =
      Path.join(System.tmp_dir!(), "grid_nest_dets_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    file = Path.join(dir, "layouts.dets")

    if Process.whereis(Dets) do
      GenServer.stop(Dets)
    end

    {:ok, _pid} = Dets.start_link(file: file)

    on_exit(fn ->
      if Process.whereis(Dets), do: GenServer.stop(Dets)
      File.rm_rf!(dir)
    end)

    :ok
  end

  test "survives process restart and reloads from disk" do
    scope = "u-persisted"
    key = Key.new(scope, "home", "desk")
    layout = Layout.new!([%{id: "a", x: 0, y: 0, w: 3, h: 3}])

    :ok = Dets.save(key, layout)

    file = :sys.get_state(Dets).file
    GenServer.stop(Dets)
    {:ok, _pid} = Dets.start_link(file: file)

    assert {:ok, ^layout} = Dets.load(key)
  end
end
