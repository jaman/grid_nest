defmodule GridNest.BootstrapTest do
  use ExUnit.Case, async: false

  alias GridNest.Bootstrap
  alias GridNest.Layout
  alias GridNest.Layout.Key
  alias GridNest.LayoutStore.Ets
  alias GridNest.LayoutStore.Noop

  setup do
    Ets.reset!()
    :ok
  end

  defp default_layout do
    Layout.new!([%{id: "def", x: 0, y: 0, w: 2, h: 2}])
  end

  defp other_layout do
    Layout.new!([%{id: "other", x: 0, y: 0, w: 4, h: 4}])
  end

  describe "resolve/1 with a clean store" do
    test "returns the provided default when the server has no record" do
      key = Key.new("u1", "home", "b1")

      assert %Bootstrap.Result{layout: layout, source: :default} =
               Bootstrap.resolve(%{
                 adapter: Noop,
                 key: key,
                 default_layout: default_layout(),
                 new_browser_fallback: :default
               })

      assert layout == default_layout()
    end

    test "falls back to adapter default/1 when no default_layout is passed" do
      key = Key.new("u1", "home", "b1")

      assert %Bootstrap.Result{layout: [], source: :default} =
               Bootstrap.resolve(%{
                 adapter: Noop,
                 key: key,
                 default_layout: nil,
                 new_browser_fallback: :default
               })
    end
  end

  describe "resolve/1 with an exact hit" do
    test "returns the stored layout for the exact browser_hash" do
      key = Key.new("u1", "home", "desk")
      stored = other_layout()
      :ok = Ets.save(key, stored)

      assert %Bootstrap.Result{layout: ^stored, source: :server_exact} =
               Bootstrap.resolve(%{
                 adapter: Ets,
                 key: key,
                 default_layout: nil,
                 new_browser_fallback: :most_recent
               })
    end
  end

  describe "resolve/1 with :most_recent fallback" do
    test "returns another browser's layout when this browser has no record" do
      scope = "u-fallback"
      :ok = Ets.save(Key.new(scope, "home", "desk"), other_layout())

      new_key = Key.new(scope, "home", "new-browser")

      assert %Bootstrap.Result{source: :server_any_browser, layout: layout} =
               Bootstrap.resolve(%{
                 adapter: Ets,
                 key: new_key,
                 default_layout: nil,
                 new_browser_fallback: :most_recent
               })

      assert layout == other_layout()
    end

    test "falls through to default when no layout exists for any browser" do
      key = Key.new("u-empty", "home", "new")

      assert %Bootstrap.Result{source: :default, layout: layout} =
               Bootstrap.resolve(%{
                 adapter: Ets,
                 key: key,
                 default_layout: default_layout(),
                 new_browser_fallback: :most_recent
               })

      assert layout == default_layout()
    end
  end

  describe "resolve/1 with :default fallback" do
    test "ignores cross-browser layouts even when one exists" do
      scope = "u-strict"
      :ok = Ets.save(Key.new(scope, "home", "desk"), other_layout())

      new_key = Key.new(scope, "home", "new-browser")

      assert %Bootstrap.Result{source: :default, layout: layout} =
               Bootstrap.resolve(%{
                 adapter: Ets,
                 key: new_key,
                 default_layout: default_layout(),
                 new_browser_fallback: :default
               })

      assert layout == default_layout()
    end
  end

  describe "resolve/1 filters stored layout to match default_layout IDs" do
    test "exact hit excludes panels not present in default_layout" do
      key = Key.new("u-filter", "home", "desk")

      stored =
        Layout.new!([
          %{id: "panel-a", x: 0, y: 0, w: 2, h: 2},
          %{id: "panel-b", x: 2, y: 0, w: 2, h: 2},
          %{id: "panel-c", x: 4, y: 0, w: 2, h: 2}
        ])

      :ok = Ets.save(key, stored)

      visible_default =
        Layout.new!([
          %{id: "panel-a", x: 0, y: 0, w: 2, h: 2},
          %{id: "panel-c", x: 4, y: 0, w: 2, h: 2}
        ])

      assert %Bootstrap.Result{source: :server_exact, layout: layout} =
               Bootstrap.resolve(%{
                 adapter: Ets,
                 key: key,
                 default_layout: visible_default,
                 new_browser_fallback: :default
               })

      ids = Enum.map(layout, & &1.id)
      assert "panel-a" in ids
      assert "panel-c" in ids
      refute "panel-b" in ids
    end

    test "any_browser hit excludes panels not present in default_layout" do
      scope = "u-filter-any"

      stored =
        Layout.new!([
          %{id: "panel-a", x: 0, y: 0, w: 2, h: 2},
          %{id: "panel-b", x: 2, y: 0, w: 2, h: 2}
        ])

      :ok = Ets.save(Key.new(scope, "home", "old-browser"), stored)

      visible_default =
        Layout.new!([%{id: "panel-a", x: 0, y: 0, w: 2, h: 2}])

      assert %Bootstrap.Result{source: :server_any_browser, layout: layout} =
               Bootstrap.resolve(%{
                 adapter: Ets,
                 key: Key.new(scope, "home", "new-browser"),
                 default_layout: visible_default,
                 new_browser_fallback: :most_recent
               })

      ids = Enum.map(layout, & &1.id)
      assert "panel-a" in ids
      refute "panel-b" in ids
    end

    test "does not filter when default_layout is nil" do
      key = Key.new("u-filter-nil", "home", "desk")

      stored =
        Layout.new!([
          %{id: "panel-a", x: 0, y: 0, w: 2, h: 2},
          %{id: "panel-b", x: 2, y: 0, w: 2, h: 2}
        ])

      :ok = Ets.save(key, stored)

      assert %Bootstrap.Result{source: :server_exact, layout: layout} =
               Bootstrap.resolve(%{
                 adapter: Ets,
                 key: key,
                 default_layout: nil,
                 new_browser_fallback: :default
               })

      assert length(layout) == 2
    end
  end

  describe "resolve/1 error handling" do
    test "raises on unknown fallback strategy" do
      assert_raise ArgumentError, fn ->
        Bootstrap.resolve(%{
          adapter: Noop,
          key: Key.new("u", "home", "b"),
          default_layout: default_layout(),
          new_browser_fallback: :bogus
        })
      end
    end
  end
end
