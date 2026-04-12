defmodule GridNest.AppJsPatcherTest do
  use ExUnit.Case, async: true

  alias GridNest.AppJsPatcher

  describe "patch/1" do
    test "adds an import at the top when none is present" do
      input = ~s|import {LiveSocket} from "phoenix_live_view"\n|
      output = AppJsPatcher.patch(input)
      assert output =~ ~s|import { GridNestBoard } from "../vendor/grid_nest.js"|
    end

    test "adds a hooks key to the LiveSocket config when missing" do
      input = """
      import { Socket } from "phoenix"
      import { LiveSocket } from "phoenix_live_view"

      let liveSocket = new LiveSocket("/live", Socket, {
        params: {_csrf_token: csrfToken}
      })
      """

      output = AppJsPatcher.patch(input)
      assert output =~ "hooks: { GridNestBoard }"
    end

    test "merges GridNestBoard into an existing hooks object" do
      input = """
      import { Socket } from "phoenix"
      import { LiveSocket } from "phoenix_live_view"

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { MyHook },
        params: {_csrf_token: csrfToken}
      })
      """

      output = AppJsPatcher.patch(input)
      assert output =~ "GridNestBoard"
      assert output =~ "MyHook"
    end

    test "is idempotent when GridNestBoard is already imported and registered" do
      input = """
      import { GridNestBoard } from "../vendor/grid_nest.js"

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { GridNestBoard },
        params: {_csrf_token: csrfToken}
      })
      """

      output = AppJsPatcher.patch(input)

      import_count =
        output |> String.split(~s(from "../vendor/grid_nest.js")) |> length()

      assert import_count == 2
      hook_occurrences = output |> String.split("GridNestBoard") |> length()
      assert hook_occurrences <= 3
    end

    test "inserts the import after the last top-of-file import" do
      input = """
      import { Socket } from "phoenix"
      import { LiveSocket } from "phoenix_live_view"
      import topbar from "topbar"

      const x = 1
      """

      output = AppJsPatcher.patch(input)

      lines = String.split(output, "\n")

      topbar_idx = Enum.find_index(lines, &String.contains?(&1, "topbar"))
      grid_idx = Enum.find_index(lines, &String.contains?(&1, "GridNestBoard"))
      const_idx = Enum.find_index(lines, &String.contains?(&1, "const x"))

      assert grid_idx > topbar_idx
      assert grid_idx < const_idx
    end
  end
end
