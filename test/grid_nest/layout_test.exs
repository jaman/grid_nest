defmodule GridNest.LayoutTest do
  use ExUnit.Case, async: true

  alias GridNest.Layout
  alias GridNest.Layout.Item

  describe "new/1" do
    test "wraps a list of item maps into a validated layout" do
      assert {:ok, layout} =
               Layout.new([
                 %{id: "a", x: 0, y: 0, w: 2, h: 2},
                 %{id: "b", x: 2, y: 0, w: 2, h: 2}
               ])

      assert [%Item{id: "a"}, %Item{id: "b"}] = layout
    end

    test "passes through an already-built list of Items" do
      items = [Item.new!(%{id: "a", x: 0, y: 0, w: 1, h: 1})]
      assert {:ok, ^items} = Layout.new(items)
    end

    test "rejects layouts with duplicate ids" do
      assert {:error, {:duplicate_id, "a"}} =
               Layout.new([
                 %{id: "a", x: 0, y: 0, w: 1, h: 1},
                 %{id: "a", x: 1, y: 0, w: 1, h: 1}
               ])
    end

    test "rejects layouts with overlapping items" do
      assert {:error, {:collision, "a", "b"}} =
               Layout.new([
                 %{id: "a", x: 0, y: 0, w: 2, h: 2},
                 %{id: "b", x: 1, y: 1, w: 2, h: 2}
               ])
    end

    test "surfaces per-item validation errors" do
      assert {:error, {:item, _, {:invalid, :w}}} =
               Layout.new([%{id: "a", x: 0, y: 0, w: 0, h: 1}])
    end
  end

  describe "to_wire/1" do
    test "serialises to a list of plain maps suitable for JSON" do
      {:ok, layout} = Layout.new([%{id: "a", x: 0, y: 0, w: 2, h: 3}])

      assert [%{id: "a", x: 0, y: 0, w: 2, h: 3}] = Layout.to_wire(layout)
    end
  end
end
