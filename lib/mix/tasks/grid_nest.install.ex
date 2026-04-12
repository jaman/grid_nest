if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.GridNest.Install do
    @shortdoc "Installs GridNest into a Phoenix application"

    @moduledoc """
    Installs GridNest into a host Phoenix application.

    By default this:

      * copies the JS hook into `assets/vendor/grid_nest.js`, ready to be
        imported and registered in the host's `app.js`;
      * writes `priv/grid_nest/INSTALL.md`, a short README describing the
        remaining manual steps (registering the hook, mounting the
        `GridNest.Board` component, optionally wiring tailwind).

    With the `--with-ash-store` flag, it also scaffolds a
    `<HostApp>.GridNest.LayoutStore` module ready to be backed by an Ash
    resource.

        mix grid_nest.install
        mix grid_nest.install --with-ash-store
    """

    use Igniter.Mix.Task

    @hook_source Path.expand("../../../assets/js/grid_nest.js", __DIR__)
    @external_resource @hook_source
    @hook_contents File.read!(@hook_source)

    @css_source Path.expand("../../../assets/css/grid_nest.css", __DIR__)
    @external_resource @css_source
    @css_contents File.read!(@css_source)

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        schema: [with_ash_store: :boolean, yes: :boolean],
        defaults: [with_ash_store: false, yes: false]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> install_js_hook()
      |> install_css()
      |> patch_app_js()
      |> maybe_install_ash_store()
    end

    defp install_js_hook(igniter) do
      Igniter.create_new_file(igniter, "assets/vendor/grid_nest.js", @hook_contents,
        on_exists: :overwrite
      )
    end

    defp install_css(igniter) do
      Igniter.create_new_file(igniter, "assets/vendor/grid_nest.css", @css_contents,
        on_exists: :overwrite
      )
    end

    defp patch_app_js(igniter) do
      path = "assets/js/app.js"

      if Igniter.exists?(igniter, path) do
        Igniter.update_file(igniter, path, fn source ->
          content = Rewrite.Source.get(source, :content)
          Rewrite.Source.update(source, :content, GridNest.AppJsPatcher.patch(content))
        end)
      else
        igniter
      end
    end

    defp maybe_install_ash_store(igniter) do
      if igniter.args.options[:with_ash_store] do
        install_ash_store(igniter)
      else
        igniter
      end
    end

    defp install_ash_store(igniter) do
      app_module = Igniter.Project.Module.module_name(igniter, "GridNest.LayoutStore")
      path = Igniter.Project.Module.proper_location(igniter, app_module)

      Igniter.create_new_file(igniter, path, ash_store_stub(app_module), on_exists: :skip)
    end

    defp ash_store_stub(app_module) do
      """
      defmodule #{inspect(app_module)} do
        @moduledoc \"\"\"
        Ash-backed `GridNest.LayoutStore` adapter scaffolded by
        `mix grid_nest.install --with-ash-store`.

        Replace the stub callbacks with calls into your Ash domain/resource.
        \"\"\"

        @behaviour GridNest.LayoutStore

        alias GridNest.Layout.Key

        @impl true
        def load(%Key{} = _key), do: :miss

        @impl true
        def load_any_browser(%Key{} = _key), do: :miss

        @impl true
        def save(%Key{} = _key, _layout), do: :ok

        @impl true
        def default(_page_key), do: []
      end
      """
    end
  end
end
