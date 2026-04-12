defmodule GridNest.BoardSlotTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias GridNest.Layout
  alias GridNest.LayoutStore.Noop

  @endpoint GridNest.TestEndpoint

  defp default_layout do
    Layout.new!([
      %{id: "w-a", x: 0, y: 0, w: 2, h: 2},
      %{id: "w-b", x: 2, y: 0, w: 2, h: 2}
    ])
  end

  defp mount_harness(harness) do
    session = %{
      "user_scope" => "u-#{System.unique_integer([:positive])}",
      "page_key" => "home",
      "browser_hash" => "desk",
      "server_storage" => Noop,
      "client_storage" => :none,
      "default_layout" => default_layout(),
      "new_browser_fallback" => :most_recent
    }

    conn = Plug.Test.init_test_session(build_conn(), %{})
    live_isolated(conn, harness, session: session)
  end

  test "renders the :tile slot once per item with the item bound as :let" do
    {:ok, _lv, html} = mount_harness(GridNest.BoardSlotHarness)

    assert html =~ ~s(<span class="tile-label">w-a</span>)
    assert html =~ ~s(<span class="tile-label">w-b</span>)
  end

  test "empty grid renders without the slot body when layout is empty" do
    {:ok, _lv, html} = mount_harness(GridNest.BoardSlotEmptyHarness)

    refute html =~ "tile-label"
  end
end
