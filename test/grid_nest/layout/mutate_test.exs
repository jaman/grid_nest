defmodule GridNest.Layout.MutateTest do
  use ExUnit.Case, async: true

  alias GridNest.Layout
  alias GridNest.Layout.Item
  alias GridNest.Layout.Mutate

  defp layout(items), do: Layout.new!(items)

  describe "move/3" do
    test "moves a tile to a free slot without touching siblings" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 2, y: 0, w: 2, h: 2}
        ])

      assert {:ok, moved} = Mutate.move(layout, "a", %{x: 4, y: 0})
      assert Enum.find(moved, &(&1.id == "a")) == %Item{id: "a", x: 4, y: 0, w: 2, h: 2}
      assert Enum.find(moved, &(&1.id == "b")) == %Item{id: "b", x: 2, y: 0, w: 2, h: 2}
    end

    test "returns an error when the tile id is not in the layout" do
      layout = layout([%{id: "a", x: 0, y: 0, w: 1, h: 1}])
      assert {:error, {:not_found, "ghost"}} = Mutate.move(layout, "ghost", %{x: 1, y: 1})
    end

    test "rejects negative destination coordinates" do
      layout = layout([%{id: "a", x: 0, y: 0, w: 1, h: 1}])
      assert {:error, {:invalid, :x}} = Mutate.move(layout, "a", %{x: -1, y: 0})
      assert {:error, {:invalid, :y}} = Mutate.move(layout, "a", %{x: 0, y: -1})
    end

    test "pushes colliding siblings down to make room" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 2, y: 0, w: 2, h: 2}
        ])

      {:ok, moved} = Mutate.move(layout, "a", %{x: 2, y: 0})

      assert Enum.find(moved, &(&1.id == "a")).y == 0
      assert Enum.find(moved, &(&1.id == "a")).x == 2
      assert Enum.find(moved, &(&1.id == "b")).y >= 2
    end

    test "cascades: a pushed tile in turn pushes another tile" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 2, y: 0, w: 2, h: 2},
          %{id: "c", x: 2, y: 2, w: 2, h: 2}
        ])

      {:ok, moved} = Mutate.move(layout, "a", %{x: 2, y: 0})

      b = Enum.find(moved, &(&1.id == "b"))
      c = Enum.find(moved, &(&1.id == "c"))
      assert b.y >= 2
      assert c.y >= b.y + b.h
    end
  end

  describe "resize/3" do
    test "grows a tile in place when the new footprint is free" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 6, y: 0, w: 2, h: 2}
        ])

      assert {:ok, resized} = Mutate.resize(layout, "a", %{w: 4, h: 3})

      a = Enum.find(resized, &(&1.id == "a"))
      assert a.w == 4
      assert a.h == 3
      assert a.x == 0
      assert a.y == 0
    end

    test "pushes collided tiles down" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 2, y: 0, w: 2, h: 2}
        ])

      {:ok, resized} = Mutate.resize(layout, "a", %{w: 4, h: 2})

      b = Enum.find(resized, &(&1.id == "b"))
      assert b.y >= 2
    end

    test "rejects non-positive dimensions" do
      layout = layout([%{id: "a", x: 0, y: 0, w: 1, h: 1}])
      assert {:error, {:invalid, :w}} = Mutate.resize(layout, "a", %{w: 0, h: 1})
      assert {:error, {:invalid, :h}} = Mutate.resize(layout, "a", %{w: 1, h: 0})
    end

    test "returns not_found when the tile id is unknown" do
      layout = layout([%{id: "a", x: 0, y: 0, w: 1, h: 1}])
      assert {:error, {:not_found, "nope"}} = Mutate.resize(layout, "nope", %{w: 1, h: 1})
    end
  end

  describe "compact/1" do
    test "pulls items up into gaps while preserving their x coordinate" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 2, y: 4, w: 2, h: 2}
        ])

      compacted = Mutate.compact(layout)

      assert Enum.find(compacted, &(&1.id == "b")).y == 0
      assert Enum.find(compacted, &(&1.id == "b")).x == 2
    end

    test "respects ordering — items higher in the list anchor the packing" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 4, h: 2},
          %{id: "b", x: 0, y: 6, w: 2, h: 2},
          %{id: "c", x: 2, y: 6, w: 2, h: 2}
        ])

      compacted = Mutate.compact(layout)

      assert Enum.find(compacted, &(&1.id == "a")).y == 0
      assert Enum.find(compacted, &(&1.id == "b")).y == 2
      assert Enum.find(compacted, &(&1.id == "c")).y == 2
    end

    test "is idempotent on an already-compact layout" do
      input =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 2, y: 0, w: 2, h: 2}
        ])

      assert Mutate.compact(input) == input
    end
  end

  describe "movable/resizable flags" do
    test "move/3 rejects a non-movable tile" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2, movable: false},
          %{id: "b", x: 2, y: 0, w: 2, h: 2}
        ])

      assert {:error, :not_movable} = Mutate.move(layout, "a", %{x: 4, y: 0})
    end

    test "resize/3 rejects a non-resizable tile" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2, resizable: false},
          %{id: "b", x: 4, y: 0, w: 2, h: 2}
        ])

      assert {:error, :not_resizable} = Mutate.resize(layout, "a", %{w: 3, h: 2})
    end

    test "move/3 refuses to cascade a non-movable sibling" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "wall", x: 2, y: 0, w: 2, h: 2, movable: false}
        ])

      assert {:error, {:blocked_by, "wall"}} = Mutate.move(layout, "a", %{x: 2, y: 0})
    end

    test "resize/3 refuses to push a non-movable sibling out of the way" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "wall", x: 2, y: 0, w: 2, h: 2, movable: false}
        ])

      assert {:error, {:blocked_by, "wall"}} = Mutate.resize(layout, "a", %{w: 4, h: 2})
    end

    test "default flags are both true" do
      [item] = layout([%{id: "a", x: 0, y: 0, w: 1, h: 1}])
      assert item.movable == true
      assert item.resizable == true
    end
  end

  describe "collapse/2" do
    test ":vertical pulls tiles up into vertical gaps without changing x" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 0, y: 6, w: 2, h: 2},
          %{id: "c", x: 4, y: 8, w: 2, h: 2}
        ])

      collapsed = Mutate.collapse(layout, :vertical)

      a = Enum.find(collapsed, &(&1.id == "a"))
      b = Enum.find(collapsed, &(&1.id == "b"))
      c = Enum.find(collapsed, &(&1.id == "c"))

      assert a.y == 0
      assert b.y == 2
      assert c.y == 0
      assert c.x == 4
    end

    test ":horizontal pulls tiles left into horizontal gaps without changing y" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 6, y: 0, w: 2, h: 2},
          %{id: "c", x: 0, y: 4, w: 2, h: 2}
        ])

      collapsed = Mutate.collapse(layout, :horizontal)

      a = Enum.find(collapsed, &(&1.id == "a"))
      b = Enum.find(collapsed, &(&1.id == "b"))
      c = Enum.find(collapsed, &(&1.id == "c"))

      assert a.x == 0
      assert b.x == 2
      assert b.y == 0
      assert c.x == 0
      assert c.y == 4
    end

    test ":both collapses vertically then horizontally" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 6, y: 6, w: 2, h: 2}
        ])

      collapsed = Mutate.collapse(layout, :both)

      b = Enum.find(collapsed, &(&1.id == "b"))
      assert b.y == 0
      assert b.x == 2
    end

    test ":none returns the layout unchanged" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 6, y: 6, w: 2, h: 2}
        ])

      assert Mutate.collapse(layout, :none) == layout
    end

    test "collapse is idempotent" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 0, y: 6, w: 2, h: 2},
          %{id: "c", x: 4, y: 8, w: 2, h: 2}
        ])

      once = Mutate.collapse(layout, :vertical)
      twice = Mutate.collapse(once, :vertical)
      assert Enum.sort_by(once, & &1.id) == Enum.sort_by(twice, & &1.id)
    end

    test "collapse never produces overlaps" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 4, h: 2},
          %{id: "b", x: 2, y: 6, w: 4, h: 2},
          %{id: "c", x: 6, y: 8, w: 2, h: 2}
        ])

      for mode <- [:vertical, :horizontal, :both] do
        collapsed = Mutate.collapse(layout, mode)
        assert {:ok, _} = Layout.new(collapsed), "overlap detected with mode #{mode}"
      end
    end
  end

  describe "move/3 + compact pipeline" do
    test "a move followed by compact never leaves overlaps" do
      layout =
        layout([
          %{id: "a", x: 0, y: 0, w: 2, h: 2},
          %{id: "b", x: 2, y: 0, w: 2, h: 2},
          %{id: "c", x: 4, y: 0, w: 2, h: 2}
        ])

      {:ok, moved} = Mutate.move(layout, "c", %{x: 0, y: 0})
      compacted = Mutate.compact(moved)

      assert {:ok, _} = Layout.new(compacted)
    end
  end
end
