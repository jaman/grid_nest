defmodule GridNest.LayoutStore.NoopTest do
  use ExUnit.Case, async: true

  alias GridNest.Layout.Key
  alias GridNest.LayoutStore
  alias GridNest.LayoutStore.Noop

  describe "Noop" do
    test "load always returns :miss" do
      assert :miss = LayoutStore.load(Noop, Key.new("u1", "home", "b1"))
    end

    test "load_any_browser always returns :miss" do
      assert :miss = LayoutStore.load_any_browser(Noop, Key.any_browser("u1", "home"))
    end

    test "save always succeeds and discards the layout" do
      assert :ok = LayoutStore.save(Noop, Key.new("u1", "home", "b1"), [])
      assert :miss = LayoutStore.load(Noop, Key.new("u1", "home", "b1"))
    end

    test "default returns an empty layout" do
      assert [] = LayoutStore.default(Noop, "home")
    end
  end
end
