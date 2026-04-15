defmodule GridNest.HydrateTest do
  use ExUnit.Case, async: true

  alias GridNest.Bootstrap.Result, as: BootstrapResult
  alias GridNest.Hydrate
  alias GridNest.Layout

  defp server_layout do
    Layout.new!([%{id: "srv", x: 0, y: 0, w: 2, h: 2}])
  end

  defp client_layout do
    Layout.new!([%{id: "srv", x: 0, y: 0, w: 4, h: 4}])
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

  describe "resolve/2 server_exact ignores client" do
    test "keeps server layout even when client has a different layout" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :server_exact}

      assert %Hydrate.Decision{
               layout: layout,
               action: :keep,
               persist_to_server?: false
             } = Hydrate.resolve(bootstrap, client_layout())

      assert layout == server_layout()
    end

    test "keeps server layout when client matches" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :server_exact}

      assert %Hydrate.Decision{action: :keep, persist_to_server?: false} =
               Hydrate.resolve(bootstrap, server_layout())
    end
  end

  describe "resolve/2 client wins on server miss" do
    test "swaps to client layout when bootstrap source is :default" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :default}

      assert %Hydrate.Decision{
               layout: layout,
               action: :swap,
               persist_to_server?: true
             } = Hydrate.resolve(bootstrap, client_layout())

      [item] = layout
      assert item.w == 4
      assert item.h == 4
    end

    test "swaps to client layout when bootstrap source is :server_any_browser" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :server_any_browser}

      assert %Hydrate.Decision{
               action: :swap,
               persist_to_server?: true
             } = Hydrate.resolve(bootstrap, client_layout())
    end

    test "still re-seeds server if client matches a :default bootstrap" do
      bootstrap = %BootstrapResult{layout: server_layout(), source: :default}

      assert %Hydrate.Decision{action: :swap, persist_to_server?: true} =
               Hydrate.resolve(bootstrap, server_layout())
    end

    test "filters client layout to only items present in bootstrap" do
      bootstrap =
        %BootstrapResult{
          layout:
            Layout.new!([
              %{id: "visible", x: 0, y: 0, w: 4, h: 2}
            ]),
          source: :default
        }

      client_with_hidden =
        Layout.new!([
          %{id: "visible", x: 0, y: 0, w: 6, h: 3},
          %{id: "hidden", x: 6, y: 0, w: 2, h: 2}
        ])

      %Hydrate.Decision{layout: merged} = Hydrate.resolve(bootstrap, client_with_hidden)

      ids = Enum.map(merged, & &1.id)
      assert "visible" in ids
      refute "hidden" in ids
    end

    test "reapplies bootstrap movable/resizable flags onto client positions" do
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

      bootstrap = %BootstrapResult{layout: locked_server, source: :default}

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
