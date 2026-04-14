defmodule GridNest.LayoutStore.CachexTest do
  use GridNest.LayoutStoreCase,
    adapter: GridNest.LayoutStore.Cachex,
    supports: [:any_browser]

  alias GridNest.Layout
  alias GridNest.Layout.Key
  alias GridNest.LayoutStore.Cachex, as: CachexStore

  setup do
    Cachex.clear!(CachexStore.cache_name())
    :ok
  end

  describe "disk persistence" do
    setup do
      dir =
        Path.join(
          System.tmp_dir!(),
          "grid_nest_cachex_test_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(dir)
      disk_path = Path.join(dir, "layouts.cachex")

      on_exit(fn -> File.rm_rf!(dir) end)

      %{disk_path: disk_path}
    end

    test "survives cache restart when disk_path is configured", %{disk_path: disk_path} do
      cache_name = :"cachex_persist_test_#{System.unique_integer([:positive])}"

      {:ok, _} =
        CachexStore.start_link(name: cache_name, disk_path: disk_path)

      scope = "u-persisted-#{System.unique_integer([:positive])}"
      key = Key.new(scope, "home", "desk")
      layout = Layout.new!([%{id: "a", x: 0, y: 0, w: 3, h: 3}])

      :ok = CachexStore.save(key, layout, cache_name)

      Supervisor.stop(cache_name)

      {:ok, _} =
        CachexStore.start_link(name: cache_name, disk_path: disk_path)

      assert {:ok, ^layout} = CachexStore.load(key, cache_name)

      Supervisor.stop(cache_name)
    end

    test "does not write to disk when disk_path is not configured" do
      cache_name = :"cachex_no_persist_test_#{System.unique_integer([:positive])}"

      {:ok, _} = CachexStore.start_link(name: cache_name)

      scope = "u-mem-only-#{System.unique_integer([:positive])}"
      key = Key.new(scope, "home", "desk")
      layout = Layout.new!([%{id: "b", x: 0, y: 0, w: 2, h: 2}])

      :ok = CachexStore.save(key, layout, cache_name)
      assert {:ok, ^layout} = CachexStore.load(key, cache_name)

      Supervisor.stop(cache_name)
    end
  end
end
