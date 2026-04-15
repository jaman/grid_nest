defmodule GridNest.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/jarius/grid_nest"

  def project do
    [
      app: :grid_nest,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [ci: :test],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      source_url: @source_url,
      name: "GridNest"
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "credo --strict",
        "test",
        &test_js/1
      ]
    ]
  end

  defp test_js(_args) do
    {output, status} =
      System.cmd("node", ["--test", "js/grid_nest.test.js"],
        cd: "assets",
        stderr_to_stdout: true
      )

    IO.write(output)

    if status != 0 do
      Mix.raise("JS tests failed (exit #{status})")
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "LiveView-native draggable, resizable dashboard grids with pluggable client and server layout persistence."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv assets mix.exs README.md .formatter.exs)
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:cachex, "~> 4.0", optional: true},
      {:igniter, "~> 0.5", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:bandit, "~> 1.0", only: :dev}
    ]
  end
end
