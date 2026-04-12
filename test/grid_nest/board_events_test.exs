defmodule GridNest.BoardEventsTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias GridNest.Layout
  alias GridNest.Layout.Key
  alias GridNest.LayoutStore.Ets
  alias GridNest.LayoutStore.Noop

  @endpoint GridNest.TestEndpoint

  setup do
    Ets.reset!()
    :ok
  end

  defp default_layout do
    Layout.new!([
      %{id: "w-a", x: 0, y: 0, w: 2, h: 2},
      %{id: "w-b", x: 2, y: 0, w: 2, h: 2}
    ])
  end

  defp mount_harness(session_overrides) do
    session =
      Map.merge(
        %{
          "user_scope" => "u-#{System.unique_integer([:positive])}",
          "page_key" => "home",
          "browser_hash" => "desk",
          "server_storage" => Noop,
          "client_storage" => :local_storage,
          "default_layout" => default_layout(),
          "new_browser_fallback" => :most_recent
        },
        session_overrides
      )

    conn = Plug.Test.init_test_session(build_conn(), %{})
    live_isolated(conn, GridNest.BoardHarness, session: session)
  end

  describe "grid_nest:move" do
    test "repositions the tile and re-renders with updated styles" do
      {:ok, lv, _html} = mount_harness(%{})

      html =
        lv
        |> element("#test-board")
        |> render_hook("grid_nest:move", %{"id" => "w-a", "x" => 6, "y" => 0})

      assert html =~ ~s(data-id="w-a")
      assert html =~ "grid-column: 7 / span 2"
    end

    test "persists the moved layout to the server store" do
      scope = "u-#{System.unique_integer([:positive])}"

      {:ok, lv, _html} =
        mount_harness(%{"user_scope" => scope, "server_storage" => Ets})

      lv
      |> element("#test-board")
      |> render_hook("grid_nest:hydrate", %{"layout" => nil})

      lv
      |> element("#test-board")
      |> render_hook("grid_nest:move", %{"id" => "w-a", "x" => 6, "y" => 0})

      assert {:ok, stored} = Ets.load(Key.new(scope, "home", "desk"))
      moved = Enum.find(stored, &(&1.id == "w-a"))
      assert moved.x == 6
      assert moved.y == 0
    end

    test "pushes a grid_nest:layout_saved event back to the hook" do
      {:ok, lv, _html} = mount_harness(%{})

      lv
      |> element("#test-board")
      |> render_hook("grid_nest:move", %{"id" => "w-a", "x" => 6, "y" => 0})

      assert_push_event(lv, "grid_nest:layout_saved", %{id: "test-board"})
    end

    test "rejects an unknown tile id without crashing" do
      {:ok, lv, _html} = mount_harness(%{})

      html =
        lv
        |> element("#test-board")
        |> render_hook("grid_nest:move", %{"id" => "ghost", "x" => 6, "y" => 0})

      assert html =~ ~s(data-id="w-a")
      assert html =~ "grid-column: 1 / span 2"
    end

    test "cascades collisions by pushing siblings down" do
      {:ok, lv, _html} = mount_harness(%{})

      html =
        lv
        |> element("#test-board")
        |> render_hook("grid_nest:move", %{"id" => "w-a", "x" => 2, "y" => 0})

      assert html =~ "grid-column: 3 / span 2"
      assert html =~ "grid-row: 3 / span 2"
    end
  end

  describe "grid_nest:resize" do
    test "grows the tile and re-renders with updated styles" do
      {:ok, lv, _html} = mount_harness(%{})

      html =
        lv
        |> element("#test-board")
        |> render_hook("grid_nest:resize", %{"id" => "w-a", "w" => 4, "h" => 3})

      assert html =~ "grid-column: 1 / span 4"
      assert html =~ "grid-row: 1 / span 3"
    end

    test "rejects invalid dimensions without crashing" do
      {:ok, lv, _html} = mount_harness(%{})

      html =
        lv
        |> element("#test-board")
        |> render_hook("grid_nest:resize", %{"id" => "w-a", "w" => 0, "h" => 3})

      assert html =~ "grid-column: 1 / span 2"
    end
  end
end
