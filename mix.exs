defmodule EctoFirebird.MixProject do
  use Mix.Project

  @version "0.1.3"

  def project do
    [
      app: :ecto_firebird,
      version: @version,
      elixir: "~> 1.14",
      name: "Ecto Firebird",
      description: "Firebird Ecto3 adapter",
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/nakagami/ecto_firebird",
      package: package(),
      docs: docs(),
      deps: deps(),
      test_paths: test_paths(System.get_env("FIREBIRDEX_INTEGRATION")),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Hajime Nakagami"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/nakagami/ecto_firebird"}
    ]
  end

  defp docs() do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.11"},
      {:ecto, "~> 3.11"},
      {:firebirdex, "~> 0.3.11"},
      {:jason, ">= 0.0.0"},
      {:temp, "~> 0.4", only: [:test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(nil), do: ["test"]
  defp test_paths(_any), do: ["integration_test"]
end
