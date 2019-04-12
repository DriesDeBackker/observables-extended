defmodule Observables.MixProject do
  use Mix.Project

  def project do
    [
      app: :observables_extended,
      version: "0.1",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/m1dnight/observables"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Observables.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description() do
    "Observables in the spirit of Reactive Extensions for Elixir,
     extended with functional reactive programming tools."
  end


  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "observables_extended",
      # These are the default files included in the package
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Dries De Backker"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/m1dnight/observables"}
    ]
end
end
