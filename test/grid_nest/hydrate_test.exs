defmodule GridNest.HydrateTest do
  use ExUnit.Case, async: true

  alias GridNest.Bootstrap.Result, as: BootstrapResult
  alias GridNest.Hydrate
  alias GridNest.Layout

  defp server_layout do
    Layout.new!([%{id: "srv", x: 0, y: 0, w: 2, h: 2}])
  end

  defp client_layout do
    Layout.new!([%{id: "cli", x: 0, y: 0, w: 4, h: 4}])
  end

  describe "resolve/2 with no client layout" do
    test "keeps the server-resolved layout" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :server_exact}

      assert %Hydrate.Decision{
               layout: layout,
               action: :keep,
               persist_to_server?: false
             } = Hydrate.resolve(bootstrap, nil)

      assert layout == server_layout()
    end

    test "does not schedule a server re-seed for a server-sourced layout" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :server_exact}
      assert %Hydrate.Decision{persist_to_server?: false} = Hydrate.resolve(bootstrap, nil)
    end

    test "schedules a server re-seed when bootstrap fell through to :default" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :default}

      assert %Hydrate.Decision{
               action: :keep,
               persist_to_server?: true
             } = Hydrate.resolve(bootstrap, nil)
    end

    test "schedules a server re-seed when bootstrap used cross-browser fallback" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :server_any_browser}

      assert %Hydrate.Decision{
               action: :keep,
               persist_to_server?: true
             } = Hydrate.resolve(bootstrap, nil)
    end
  end

  describe "resolve/2 with a client layout" do
    test "swaps to the client layout and re-seeds the server" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :server_exact}

      assert %Hydrate.Decision{
               layout: layout,
               action: :swap,
               persist_to_server?: true
             } = Hydrate.resolve(bootstrap, client_layout())

      assert layout == client_layout()
    end

    test "keeps (does not swap) when the client layout equals the server layout" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :server_exact}

      assert %Hydrate.Decision{action: :keep, persist_to_server?: false} =
               Hydrate.resolve(bootstrap, server_layout())
    end

    test "still re-seeds server if client matches a :default bootstrap" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :default}

      assert %Hydrate.Decision{action: :keep, persist_to_server?: true} =
               Hydrate.resolve(bootstrap, server_layout())
    end

    test "reapplies bootstrap movable/resizable flags onto client positions by id" do
      locked_server =
        Layout.new!([
          %{id: "header", x: 0, y: 0, w: 12, h: 2, movable: false, resizable: false},
          %{id: "body", x: 0, y: 2, w: 6, h: 4}
        ])

      client_positions_only =
        Layout.new!([
          %{id: "header", x: 0, y: 0, w: 12, h: 2},
          %{id: "body", x: 6, y: 2, w: 6, h: 4}
        ])

      bootstrap = %BootstrapResult{layout: locked_server, source: :server_exact}

      %Hydrate.Decision{layout: merged} = Hydrate.resolve(bootstrap, client_positions_only)

      header = Enum.find(merged, &(&1.id == "header"))
      body = Enum.find(merged, &(&1.id == "body"))

      assert header.movable == false
      assert header.resizable == false
      assert body.movable == true
      assert body.resizable == true
      assert body.x == 6
    end
  end
end
