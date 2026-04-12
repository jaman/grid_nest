defmodule GridNest.BoardTest do
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

  defp stored_layout do
    Layout.new!([%{id: "w-srv", x: 0, y: 0, w: 4, h: 3}])
  end

  defp client_layout do
    Layout.new!([%{id: "w-cli", x: 1, y: 1, w: 6, h: 4}])
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

  describe "initial render" do
    test "uses the default layout when server storage has no record" do
      {:ok, lv, html} = mount_harness(%{})

      assert html =~ ~s(data-id="w-a")
      assert html =~ ~s(data-id="w-b")
      assert html =~ ~s(id="test-board")
      assert render(lv) =~ ~s(phx-hook="GridNestBoard")
    end

    test "renders tiles with CSS-grid column/row styles derived from coordinates" do
      {:ok, _lv, html} = mount_harness(%{})

      assert html =~ "grid-column: 1 / span 2"
      assert html =~ "grid-column: 3 / span 2"
      assert html =~ "grid-row: 1 / span 2"
    end

    test "renders the server layout when a record exists for the exact key" do
      scope = "u-#{System.unique_integer([:positive])}"
      :ok = Ets.save(Key.new(scope, "home", "desk"), stored_layout())

      {:ok, _lv, html} =
        mount_harness(%{"user_scope" => scope, "server_storage" => Ets})

      assert html =~ ~s(data-id="w-srv")
      refute html =~ ~s(data-id="w-a")
    end

    test "uses cross-browser fallback with :most_recent strategy" do
      scope = "u-#{System.unique_integer([:positive])}"
      :ok = Ets.save(Key.new(scope, "home", "other"), stored_layout())

      {:ok, _lv, html} =
        mount_harness(%{
          "user_scope" => scope,
          "server_storage" => Ets,
          "browser_hash" => "brand-new",
          "new_browser_fallback" => :most_recent
        })

      assert html =~ ~s(data-id="w-srv")
    end

    test "ignores cross-browser layouts with :default strategy" do
      scope = "u-#{System.unique_integer([:positive])}"
      :ok = Ets.save(Key.new(scope, "home", "other"), stored_layout())

      {:ok, _lv, html} =
        mount_harness(%{
          "user_scope" => scope,
          "server_storage" => Ets,
          "browser_hash" => "brand-new",
          "new_browser_fallback" => :default
        })

      assert html =~ ~s(data-id="w-a")
      refute html =~ ~s(data-id="w-srv")
    end

    test "pushes a request_hydrate event to the hook on mount" do
      {:ok, lv, _html} = mount_harness(%{})

      assert_push_event(lv, "grid_nest:request_hydrate", %{id: "test-board"})
    end
  end

  describe "handle_event hydrate" do
    test "keeps the server layout when client reports no layout" do
      scope = "u-#{System.unique_integer([:positive])}"
      :ok = Ets.save(Key.new(scope, "home", "desk"), stored_layout())

      {:ok, lv, _html} =
        mount_harness(%{"user_scope" => scope, "server_storage" => Ets})

      html =
        lv
        |> element("#test-board")
        |> render_hook("grid_nest:hydrate", %{"layout" => nil})

      assert html =~ ~s(data-id="w-srv")
    end

    test "swaps to the client layout when the client reports one" do
      {:ok, lv, _html} = mount_harness(%{})

      html =
        lv
        |> element("#test-board")
        |> render_hook("grid_nest:hydrate", %{"layout" => Layout.to_wire(client_layout())})

      assert html =~ ~s(data-id="w-cli")
      refute html =~ ~s(data-id="w-a")
    end

    test "persists the client layout to the server store on swap" do
      scope = "u-#{System.unique_integer([:positive])}"

      {:ok, lv, _html} =
        mount_harness(%{"user_scope" => scope, "server_storage" => Ets})

      client = client_layout()

      lv
      |> element("#test-board")
      |> render_hook("grid_nest:hydrate", %{"layout" => Layout.to_wire(client)})

      assert {:ok, ^client} = Ets.load(Key.new(scope, "home", "desk"))
    end

    test "re-seeds the server when hydrate keeps a :default-sourced layout" do
      scope = "u-#{System.unique_integer([:positive])}"

      {:ok, lv, _html} =
        mount_harness(%{"user_scope" => scope, "server_storage" => Ets})

      lv
      |> element("#test-board")
      |> render_hook("grid_nest:hydrate", %{"layout" => nil})

      expected = default_layout()
      assert {:ok, ^expected} = Ets.load(Key.new(scope, "home", "desk"))
    end
  end
end
