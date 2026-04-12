defmodule GridNest.Layout.KeyTest do
  use ExUnit.Case, async: true

  alias GridNest.Layout.Key

  describe "new/3" do
    test "builds a key from the three components" do
      assert %Key{user_scope: "u1", page_key: "home", browser_hash: "b1"} =
               Key.new("u1", "home", "b1")
    end

    test "accepts non-string user scopes" do
      assert %Key{user_scope: 42} = Key.new(42, "home", "b1")
      assert %Key{user_scope: {:guest, "tok"}} = Key.new({:guest, "tok"}, "home", "b1")
    end

    test "rejects non-binary page_key" do
      assert_raise ArgumentError, fn -> Key.new("u1", :home, "b1") end
    end

    test "rejects non-binary browser_hash" do
      assert_raise ArgumentError, fn -> Key.new("u1", "home", nil) end
    end
  end

  describe "any_browser/2" do
    test "builds a wildcard key used for cross-browser fallback lookups" do
      assert %Key{user_scope: "u1", page_key: "home", browser_hash: :any} =
               Key.any_browser("u1", "home")
    end
  end
end
