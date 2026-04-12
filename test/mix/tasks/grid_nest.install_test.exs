defmodule Mix.Tasks.GridNest.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  describe "grid_nest.install" do
    test "copies the JS hook into the host app's assets/vendor directory" do
      test_project()
      |> Igniter.compose_task("grid_nest.install", ["--yes"])
      |> assert_creates("assets/vendor/grid_nest.js")
    end

    test "--with-ash-store scaffolds an adapter module in the host app" do
      test_project(app_name: :my_app)
      |> Igniter.compose_task("grid_nest.install", ["--yes", "--with-ash-store"])
      |> assert_creates("lib/my_app/grid_nest/layout_store.ex")
    end

    test "without --with-ash-store does not scaffold the adapter" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("grid_nest.install", ["--yes"])

      refute Map.has_key?(igniter.rewrite.sources, "lib/my_app/grid_nest/layout_store.ex")
    end

    test "ships grid_nest.css into assets/vendor" do
      test_project()
      |> Igniter.compose_task("grid_nest.install", ["--yes"])
      |> assert_creates("assets/vendor/grid_nest.css")
    end

    test "registers the GridNestBoard hook in an existing app.js" do
      test_project(
        files: %{
          "assets/js/app.js" => """
          import { Socket } from "phoenix"
          import { LiveSocket } from "phoenix_live_view"
          import topbar from "topbar"

          let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
          let liveSocket = new LiveSocket("/live", Socket, {
            longPollFallbackMs: 2500,
            params: {_csrf_token: csrfToken}
          })

          window.addEventListener("phx:page-loading-start", () => topbar.show(300))
          window.addEventListener("phx:page-loading-stop", () => topbar.hide())
          liveSocket.connect()
          window.liveSocket = liveSocket
          """
        }
      )
      |> Igniter.compose_task("grid_nest.install", ["--yes"])
      |> then(fn igniter ->
        source = igniter.rewrite.sources["assets/js/app.js"]
        assert source, "expected app.js to be patched"
        content = Rewrite.Source.get(source, :content)
        assert content =~ ~s(import { GridNestBoard } from "../vendor/grid_nest.js")
        assert content =~ "hooks:"
        assert content =~ "GridNestBoard"
        igniter
      end)
    end

    test "is idempotent on a re-run — does not double-import on app.js" do
      app_js = """
      import { Socket } from "phoenix"
      import { LiveSocket } from "phoenix_live_view"
      import { GridNestBoard } from "../vendor/grid_nest.js"

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { GridNestBoard },
        params: {_csrf_token: "x"}
      })
      liveSocket.connect()
      """

      igniter =
        test_project(files: %{"assets/js/app.js" => app_js})
        |> Igniter.compose_task("grid_nest.install", ["--yes"])

      source = igniter.rewrite.sources["assets/js/app.js"]

      if source do
        content = Rewrite.Source.get(source, :content)
        import_count = content |> String.split(~s(from "../vendor/grid_nest.js")) |> length()
        assert import_count <= 2
      end
    end
  end
end
