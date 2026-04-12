defmodule GridNest.BrowserHashTest do
  use ExUnit.Case, async: true

  alias GridNest.BrowserHash

  describe "BrowserHash.Plug" do
    test "generates a fresh hash and sets a cookie when none is present" do
      conn =
        :get
        |> Plug.Test.conn("/")
        |> Plug.Test.init_test_session(%{})
        |> BrowserHash.Plug.call(BrowserHash.Plug.init([]))

      hash = conn.assigns[:grid_nest_browser_hash]
      assert is_binary(hash)
      assert byte_size(hash) > 0

      cookie = conn.resp_cookies["grid_nest_browser_hash"]
      assert cookie.value == hash
      assert cookie.http_only == true
    end

    test "reuses an existing cookie when present" do
      conn =
        :get
        |> Plug.Test.conn("/")
        |> Plug.Test.put_req_cookie("grid_nest_browser_hash", "abc-xyz")
        |> Plug.Test.init_test_session(%{})
        |> BrowserHash.Plug.call(BrowserHash.Plug.init([]))

      assert conn.assigns[:grid_nest_browser_hash] == "abc-xyz"
      refute Map.has_key?(conn.resp_cookies, "grid_nest_browser_hash")
    end

    test "stores the hash in the session so LiveView mounts can read it" do
      conn =
        :get
        |> Plug.Test.conn("/")
        |> Plug.Test.init_test_session(%{})
        |> BrowserHash.Plug.call(BrowserHash.Plug.init([]))

      assert Plug.Conn.get_session(conn, :grid_nest_browser_hash) ==
               conn.assigns[:grid_nest_browser_hash]
    end
  end

  describe "BrowserHash.on_mount/4" do
    test "lifts the session hash into LiveView assigns" do
      session = %{"grid_nest_browser_hash" => "from-session"}
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}

      assert {:cont, updated} = BrowserHash.on_mount(:default, %{}, session, socket)
      assert updated.assigns.grid_nest_browser_hash == "from-session"
    end

    test "assigns an empty string when the session has no hash" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}
      assert {:cont, updated} = BrowserHash.on_mount(:default, %{}, %{}, socket)
      assert updated.assigns.grid_nest_browser_hash == ""
    end
  end
end
