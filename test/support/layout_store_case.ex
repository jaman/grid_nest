defmodule GridNest.LayoutStoreCase do
  @moduledoc """
  Shared ExUnit case template asserting the `GridNest.LayoutStore`
  behaviour contract.

  Each adapter test uses this case template and sets up an `:adapter`
  context key pointing at the module under test. The adapter is then
  exercised through the same battery of black-box checks, so any two
  adapters are held to identical guarantees.

      defmodule GridNest.LayoutStore.EtsTest do
        use GridNest.LayoutStoreCase, adapter: GridNest.LayoutStore.Ets,
                                     supports: [:any_browser]

        setup do
          GridNest.LayoutStore.Ets.reset!()
          :ok
        end
      end
  """

  use ExUnit.CaseTemplate

  using opts do
    quote do
      use ExUnit.Case, async: false

      alias GridNest.Layout
      alias GridNest.Layout.Item
      alias GridNest.Layout.Key
      alias GridNest.LayoutStore

      @adapter Keyword.fetch!(unquote(opts), :adapter)
      @supports Keyword.get(unquote(opts), :supports, [])

      defp any_browser?, do: :any_browser in @supports

      defp sample_layout(prefix \\ "a") do
        Layout.new!([
          %{id: "#{prefix}-1", x: 0, y: 0, w: 2, h: 2},
          %{id: "#{prefix}-2", x: 2, y: 0, w: 2, h: 2}
        ])
      end

      describe "contract: load/save roundtrip" do
        test "load returns :miss when nothing is stored" do
          key = Key.new("u-#{System.unique_integer()}", "home", "b1")
          assert :miss = LayoutStore.load(@adapter, key)
        end

        test "save then load returns the layout" do
          key = Key.new("u-#{System.unique_integer()}", "home", "b1")
          layout = sample_layout("rt")
          assert :ok = LayoutStore.save(@adapter, key, layout)
          assert {:ok, ^layout} = LayoutStore.load(@adapter, key)
        end

        test "save overwrites the previous layout under the same key" do
          key = Key.new("u-#{System.unique_integer()}", "home", "b1")
          assert :ok = LayoutStore.save(@adapter, key, sample_layout("first"))
          second = sample_layout("second")
          assert :ok = LayoutStore.save(@adapter, key, second)
          assert {:ok, ^second} = LayoutStore.load(@adapter, key)
        end

        test "keys are isolated by user_scope" do
          a = Key.new("user-a-#{System.unique_integer()}", "home", "b1")
          b = Key.new("user-b-#{System.unique_integer()}", "home", "b1")
          :ok = LayoutStore.save(@adapter, a, sample_layout("a"))
          assert :miss = LayoutStore.load(@adapter, b)
        end

        test "keys are isolated by page_key" do
          scope = "u-#{System.unique_integer()}"
          home = Key.new(scope, "home", "b1")
          other = Key.new(scope, "settings", "b1")
          :ok = LayoutStore.save(@adapter, home, sample_layout("home"))
          assert :miss = LayoutStore.load(@adapter, other)
        end

        test "keys are isolated by browser_hash" do
          scope = "u-#{System.unique_integer()}"
          desktop = Key.new(scope, "home", "desk")
          mobile = Key.new(scope, "home", "mob")
          :ok = LayoutStore.save(@adapter, desktop, sample_layout("desk"))
          assert :miss = LayoutStore.load(@adapter, mobile)
        end
      end

      describe "contract: load_any_browser fallback" do
        @describetag :any_browser

        test "returns :miss when the user has nothing stored" do
          if any_browser?() do
            key = Key.any_browser("u-#{System.unique_integer()}", "home")
            assert :miss = LayoutStore.load_any_browser(@adapter, key)
          end
        end

        test "returns a layout from another browser under the same user+page" do
          if any_browser?() do
            scope = "u-#{System.unique_integer()}"
            stored = Key.new(scope, "home", "desk")
            :ok = LayoutStore.save(@adapter, stored, sample_layout("desk"))

            wildcard = Key.any_browser(scope, "home")
            assert {:ok, _} = LayoutStore.load_any_browser(@adapter, wildcard)
          end
        end

        test "does not leak across user_scope" do
          if any_browser?() do
            :ok =
              LayoutStore.save(
                @adapter,
                Key.new("u-left-#{System.unique_integer()}", "home", "b1"),
                sample_layout("left")
              )

            other = Key.any_browser("u-right-#{System.unique_integer()}", "home")
            assert :miss = LayoutStore.load_any_browser(@adapter, other)
          end
        end

        test "does not leak across page_key" do
          if any_browser?() do
            scope = "u-#{System.unique_integer()}"

            :ok =
              LayoutStore.save(
                @adapter,
                Key.new(scope, "home", "b1"),
                sample_layout("home")
              )

            other = Key.any_browser(scope, "settings")
            assert :miss = LayoutStore.load_any_browser(@adapter, other)
          end
        end

        test "prefers the most recently saved layout" do
          if any_browser?() do
            scope = "u-#{System.unique_integer()}"
            first = sample_layout("first")
            second = sample_layout("second")
            :ok = LayoutStore.save(@adapter, Key.new(scope, "home", "b1"), first)
            :ok = LayoutStore.save(@adapter, Key.new(scope, "home", "b2"), second)

            wildcard = Key.any_browser(scope, "home")
            assert {:ok, ^second} = LayoutStore.load_any_browser(@adapter, wildcard)
          end
        end
      end

      describe "contract: default/1" do
        test "returns a layout list (possibly empty) for any page key" do
          assert is_list(LayoutStore.default(@adapter, "home"))
        end
      end
    end
  end
end
