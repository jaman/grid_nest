defmodule GridNest.Layout.ItemTest do
  use ExUnit.Case, async: true

  alias GridNest.Layout.Item

  describe "new/1" do
    test "builds an item with the required fields" do
      assert {:ok, %Item{id: "a", x: 0, y: 0, w: 2, h: 3}} =
               Item.new(%{id: "a", x: 0, y: 0, w: 2, h: 3})
    end

    test "accepts string-keyed maps (for decoded JSON from the hook)" do
      assert {:ok, %Item{id: "a", x: 1, y: 2, w: 3, h: 4}} =
               Item.new(%{"id" => "a", "x" => 1, "y" => 2, "w" => 3, "h" => 4})
    end

    test "rejects missing id" do
      assert {:error, {:missing, :id}} = Item.new(%{x: 0, y: 0, w: 1, h: 1})
    end

    test "rejects non-positive width or height" do
      assert {:error, {:invalid, :w}} = Item.new(%{id: "a", x: 0, y: 0, w: 0, h: 1})
      assert {:error, {:invalid, :h}} = Item.new(%{id: "a", x: 0, y: 0, w: 1, h: 0})
    end

    test "rejects negative coordinates" do
      assert {:error, {:invalid, :x}} = Item.new(%{id: "a", x: -1, y: 0, w: 1, h: 1})
      assert {:error, {:invalid, :y}} = Item.new(%{id: "a", x: 0, y: -1, w: 1, h: 1})
    end

    test "movable and resizable default to true" do
      {:ok, item} = Item.new(%{id: "a", x: 0, y: 0, w: 1, h: 1})
      assert item.movable == true
      assert item.resizable == true
    end

    test "honors explicit movable: false" do
      {:ok, item} = Item.new(%{id: "a", x: 0, y: 0, w: 1, h: 1, movable: false})
      assert item.movable == false
      assert item.resizable == true
    end

    test "honors explicit resizable: false" do
      {:ok, item} = Item.new(%{id: "a", x: 0, y: 0, w: 1, h: 1, resizable: false})
      assert item.movable == true
      assert item.resizable == false
    end

    test "accepts string-keyed flags" do
      {:ok, item} =
        Item.new(%{
          "id" => "a",
          "x" => 0,
          "y" => 0,
          "w" => 1,
          "h" => 1,
          "movable" => false,
          "resizable" => false
        })

      assert item.movable == false
      assert item.resizable == false
    end

    test "rejects non-boolean flag values" do
      assert {:error, {:invalid, :movable}} =
               Item.new(%{id: "a", x: 0, y: 0, w: 1, h: 1, movable: "nope"})
    end
  end

  describe "new!/1" do
    test "returns the struct on success" do
      assert %Item{id: "a"} = Item.new!(%{id: "a", x: 0, y: 0, w: 1, h: 1})
    end

    test "raises on invalid input" do
      assert_raise ArgumentError, fn -> Item.new!(%{id: "a", x: 0, y: 0, w: 0, h: 1}) end
    end
  end

  describe "collides?/2" do
    test "overlapping items collide" do
      a = Item.new!(%{id: "a", x: 0, y: 0, w: 2, h: 2})
      b = Item.new!(%{id: "b", x: 1, y: 1, w: 2, h: 2})
      assert Item.collides?(a, b)
    end

    test "edge-adjacent items do not collide" do
      a = Item.new!(%{id: "a", x: 0, y: 0, w: 2, h: 2})
      b = Item.new!(%{id: "b", x: 2, y: 0, w: 2, h: 2})
      refute Item.collides?(a, b)
    end

    test "an item does not collide with itself by id" do
      a = Item.new!(%{id: "a", x: 0, y: 0, w: 2, h: 2})
      refute Item.collides?(a, a)
    end
  end
end
