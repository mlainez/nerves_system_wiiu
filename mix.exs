defmodule NervesSystemWiiu.MixProject do
  use Mix.Project

  @github_organization "mlainez"
  @app :nerves_system_wiiu
  @source_url "https://github.com/#{@github_organization}/#{@app}"
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      description: description(),
      package: package(),
      deps: deps(),
      aliases: [loadconfig: [&bootstrap/1]],
      docs: docs(),
      preferred_cli_env: %{
        docs: :docs,
        "hex.build": :docs,
        "hex.publish": :docs
      }
    ]
  end

  def application do
    []
  end

  defp bootstrap(args) do
    set_target()
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  defp nerves_package do
    [
      type: :system,
      artifact_sites: [
        {:github_releases, "#{@github_organization}/#{@app}"}
      ],
      build_runner_opts: build_runner_opts(),
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      {:nerves, "~> 1.11", runtime: false},
      {:nerves_system_br, "~> 1.33", runtime: false},
      {:nerves_toolchain_wiiu_ppc, github: "mlainez/nerves_toolchain_wiiu_ppc", tag: "v13.2.0", runtime: false},
      {:nerves_system_linter, "~> 0.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false}
    ]
  end

  defp description do
    "Nerves System - Nintendo Wii U (PowerPC 750 / Espresso)"
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    [
      files: package_files(),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp package_files do
    [
      "rootfs_overlay",
      "board",
      "scripts",
      "fwup_include",
      "fwup-ops.conf",
      "fwup.conf",
      "linux-6.6.fragment",
      "linux-patches",
      "Config.in",
      "external.mk",
      "mix.exs",
      "nerves_defconfig",
      "post-build.sh",
      "post-createfs.sh",
      "README.md",
      "LICENSE",
      "VERSION"
    ]
  end

  defp build_runner_opts do
    # Download all sources up front so network errors surface immediately
    # rather than 20 minutes into the build.
    [make_args: primary_site() ++ ["source", "all", "legal-info"]]
  end

  defp primary_site do
    case System.get_env("BR2_PRIMARY_SITE") do
      nil -> []
      primary_site -> ["BR2_PRIMARY_SITE=#{primary_site}"]
    end
  end

  defp set_target do
    if function_exported?(Mix, :target, 1) do
      apply(Mix, :target, [:target])
    else
      System.put_env("MIX_TARGET", "target")
    end
  end
end
