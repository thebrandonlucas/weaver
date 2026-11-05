# Development environment and tasks for weaver, realised by Kai with Nix.
#
#     kai run check        # everything checked before the release workflow packages anything
#     kai workflow ci      # check, then the examples against the working tree
#     kai run serve        # build the documentation site and preview it
#     kai shell            # the environment, to run scripts/*.roc directly
#     kai update           # refresh .kai/lock.json
#
# `roc-stable`, pinned, runs the repository's scripts; `roc` is the latest
# Roc nightly in roc-overlay, which tests the package and examples.
# The shared roc-automation release workflow still installs roc-blueprint,
# so Blueprint.roc and Blueprint.lock stay for it. scripts/check_all.roc
# checks the scripts' compiler against Blueprint.roc's roc-stable, which
# must equal the one aliased here, and the package's dependencies against
# Blueprint.lock.
app [kaifile] {
	pf: platform "https://github.com/thebrandonlucas/kai/releases/download/v0.0.11/65bk6qdahqxn1mm6LR6Hkyw8dSdoeRZGwjNSuiPfvguP.tar.zst",
	std: "https://github.com/thebrandonlucas/kai/releases/download/v0.0.11/std-6Jw5GxNCFkpnvBbnFmQg4KAVEn5bAfEveSZfDSzTDs42.tar.zst",
}

import std.Std

automation = "https://github.com/lukewilliamboswell/roc-automation/releases/download/tools-0.9.0"

blueprint = "https://github.com/lukewilliamboswell/roc-blueprint/releases/download/0.11.0"

# A prebuilt binary per system, pinned by the SHA-256 its release publishes
# (the same as Blueprint.lock's).
binary = |name, url, x86_64_linux, aarch64_linux, aarch64_darwin| [
	Fetch(
		name,
		[
			{ system: "x86_64-linux", url: "${url}-x86_64-linux", sha256: x86_64_linux },
			{ system: "aarch64-linux", url: "${url}-aarch64-linux", sha256: aarch64_linux },
			{ system: "aarch64-darwin", url: "${url}-aarch64-darwin", sha256: aarch64_darwin },
		],
	),
]

# Roc package bundles the scripts (basic-cli, http) and the package (roc-ansi,
# path) depend on. Builds that list them in Inputs get them in Roc's package
# cache, so their header URLs resolve offline.
roc_packages = [
	Source(
		"basic-cli",
		"tarball+https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	),
	Source(
		"http",
		"tarball+https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
	),
	Source(
		"roc-ansi",
		"tarball+https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.13.3/BioPdu7WjVhTB2j1HaomKMi8htxsuwqwr79GbXY5nAUf.tar.zst",
	),
	Source(
		"path",
		"tarball+https://github.com/roc-lang/path/releases/download/4.0.0/7YfABZPwJAXtLBY2vm8FqMyGAtNxncCJ65HdNKHFGNnE.tar.zst",
	),
]

script = |name| Run(["roc-stable", "scripts/${name}.roc"])

kaifile = Std.kaifile(
	[
		Name("weaver"),
		Systems(["x86_64-linux", "aarch64-linux", "aarch64-darwin"]),
		Overlay("roc", "github:roc-lang/roc-overlay"),
		# roc-overlay's nixpkgs inputs are the project's, so they are neither
		# fetched nor locked separately.
		Follows("roc", "nixpkgs", "default"),
		Follows("roc", "nixpkgs-darwin", "default"),
		Environment(
			"dev",
			[
				Overlays(["roc"]),
				Tools(
					[
						"rocpkgs.default",
						"coreutils",
						"gh",
						"git",
						"gnutar",
						"gzip",
						"perl", # shasum
						"unzip",
						"zip",
					],
				),
				# Both roc-overlay compilers install bin/roc.
				Alias("roc-stable", "rocpkgs.\"nightly-2026-10-23-18478ff\"", "roc"),
			],
		),
		Environment("docs", [Tools(["roc-docs#roc-docs", "coreutils"])]),
		# The native SBOM tool reads its inputs without a Roc compiler.
		Environment("sbom", [Tools(["blueprint-sbom#blueprint-sbom"])]),
		# The shared release workflow's utility, run against the `roc` on PATH.
		Environment("release", [Extend("dev"), Tools(["release-package#release-package", "zstd"])]),
		Shell("default", [Use("dev")]),

		Task("check", [Use("dev"), Description("Everything checked before the release workflow packages anything"), script("check_all")]),
		Task(
			"release-package",
			[
				Use("release"),
				Description("The shared release utility, e.g. `kai run release-package -- test-examples --update`"),
				Run(["release-package"]),
			],
		),
		Task("prepare-sbom", [Use("dev"), script("prepare_sbom")]),
		Task("sbom-tool", [Use("sbom"), Run(["blueprint-sbom"])]),
		Task(
			"docs",
			[
				Use("docs"),
				Description("Render the manual as a site and a PDF"),
				Run(
					[
						"roc-docs",
						"build",
						"--workspace",
						".",
						"--docs-directory",
						"docs",
						"--entrypoint",
						"index.adoc",
						"--pdf-filename",
						"weaver.pdf",
						"--site-url",
						"https://lukewilliamboswell.github.io/weaver/",
					],
				),
			],
		),
		Task("docs-path", [Use("docs"), Run(["sh", "-c", "realpath \"$(command -v roc-docs)\""])]),
		Task("install-snippet", [Use("dev"), script("write_install_snippet")]),
		Task("site", [Use("dev"), script("build_site")]),
		Task("serve", [Use("dev"), Description("Build the documentation site and preview it"), script("serve_site")]),
		Task("capture", [Use("dev"), script("capture_example")]),
		# A dry-run release, as the shared release workflow builds it: the
		# bundle, examples archive and API docs archive, sandboxed.
		Build(
			"release",
			[
				Use("release"),
				Description("A dry-run release: bundle, examples and API docs archives"),
				Default,
				Inputs(["basic-cli", "http", "roc-ansi", "path"]),
				Env([("RP_REPOSITORY", "lukewilliamboswell/weaver")]),
				Run(["sh", "-c", "git init -q && git add -A && release-package build 0.0.1-dryrun"]),
				Output("dist"),
			],
		),
		# The archived examples, run against the dry-run bundle. It needs the
		# network to fetch the bundle's own platform, so it is a task.
		Task(
			"test-release",
			[
				Use("release"),
				Description("Run the archived examples against the dry-run bundle"),
				Needs(["release"]),
				Run(
					[
						"sh",
						"-c",
						\\set -eu
						\\rm -rf dist && mkdir dist
						\\cp "$KAI_ARTIFACTS"/release/* dist/ && chmod u+w dist/*
						\\release-package test-archive
						,
					],
				),
			],
		),
		Workflow(
			"ci",
			[
				RunTask("check", []),
				RunTask("release-package", ["test-examples"]),
			],
		),
	]
		.concat(binary("roc-docs", "${automation}/roc-docs", "0d20282f3bc14db7e9364b0b63fa3a28cbb166a4a5ffa00ec232cdce3b1a0219", "dcd00a301a875dad97c697c4585ac5bbda244291587ce917b12f9d29aeff86cf", "8239e896d835732a49ffb3ed0d4e4d7d1f4474e8f5fe7a8dbe38e7026cdb292e"))
		.concat(binary("blueprint-sbom", "${blueprint}/blueprint-sbom", "98d8587924b7a5d2eca348dfd957095c640e61975d00a62879bdf3e1f5d18f31", "7c4e59fb3cf08db5367d0049dc1f40761ca96200b7ab0592582e649f9846c93f", "772d4cdb6e99b71ccdbf8be97cb3b78cf85f70783fada4e68f2e1c6d2886bf84"))
		.concat(binary("release-package", "${automation}/release-package", "bf91e6744923145847657cae174c0324ca00794b1b1fcbec768ef6d5086834f5", "46933545000408adfebe0cc63a20b93075a0be7f20a9318a8d2246a3530f551a", "6ab66358112636b82cd116d136182176e3c7e6a2e1ee848d00ea80ceb65d10f3"))
		.concat(roc_packages),
)
