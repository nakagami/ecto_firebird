defmodule EctoFirebird.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ecto_firebird,
      version: @version,
      elixir: "~> 1.9",
      name: "Ecto Firebird",
      description: "Firebird Ecto3 adapter",
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps()
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
      licenses: ["Apache 2.0"],
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ecto_sql, "~> 3.7"},
      {:ecto, "~> 3.7"},
      {:firebirdex, "~> 0.2"},
    ]
  end
end
