# Development environment and tasks for weaver, realised by Kai without Nix.
#
#     kai run check      # everything the release workflow checks before packaging
#     kai workflow ci    # check, then the examples against the working tree
#     kai run serve      # build the documentation site and preview it
#     kai shell          # the environment, to run scripts/*.roc directly
#     kai update         # refresh .kai/lock.json
#     kai sbom inputs    # the inputs sbom/package.json disposes of
#
# `roc-stable` runs repository scripts; `roc` on PATH tests the package and
# examples on the latest nightly, so nothing here provides a bare `roc`.
# Building, testing and publishing a release is the shared roc-automation
# workflow that .github/workflows/release.yml calls; it runs the `check`,
# `prepare-sbom`, `install-snippet` and `docs-path` tasks here, and
# `kai sbom` for the SBOM sidecars.
app [kaifile] {
	pf: platform "https://github.com/thebrandonlucas/kai/releases/download/v0.0.12/G3CQ6Ed3h7vyvV4eDvwH1J8UqBv2wEtkb9jLJhFkU5ny.tar.zst",
	std: "https://github.com/thebrandonlucas/kai/releases/download/v0.0.12/std-6VuNBrdv6tT7ZAVD4bWGBYYwk1KJoXP7gCnFip5VSK11.tar.zst",
	sbom: "https://github.com/thebrandonlucas/kai/releases/download/v0.0.12/sbom-HzyZunZdK6VM3Ve3WK2cVtnFtRcTH6qUU6T65ZNG17TF.tar.zst",
}

import pf.Kaifile
import std.Config
import std.Std
import sbom.Sbom

systems = ["x86_64-linux", "aarch64-linux", "aarch64-darwin"]

# A program released as one file per system, named by the system.
file = |url| systems.map(|system| { system, url: "${url}-${system.to_str()}", mirrors: [], program: File })

roc_nightly = |tag| {
	nightly = |system, build| {
		top = "roc_nightly-${build}-${tag.drop_prefix("nightly-")}"
		{ system, url: "https://github.com/roc-lang/nightlies/releases/download/${tag}/${top}.tar.gz", mirrors: [], program: Archive("${top}/roc") }
	}
	[nightly("x86_64-linux", "linux_x86_64"), nightly("aarch64-linux", "linux_arm64"), nightly("aarch64-darwin", "macos_apple_silicon")]
}

automation = "https://github.com/lukewilliamboswell/roc-automation/releases/download/tools-0.10.1"

project : List(Config.Setting)
project = [
	Name("weaver"),
	Systems(systems),
	# The packages the bundle depends on, pinned by the SHA-256 their releases
	# publish so each supplier's SBOM can be bound to the exact file. They must
	# match the header of package/main.roc; scripts/check_all.roc checks that.
	FetchAll("roc-ansi", { url: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.13.3/BioPdu7WjVhTB2j1HaomKMi8htxsuwqwr79GbXY5nAUf.tar.zst", sha256: "93750a9b9993e4e2996feac0ddd6f199b6f3fd9ba81154a74f09f47481e1e2ba" }),
	FetchAll("path", { url: "https://github.com/roc-lang/path/releases/download/4.0.0/7YfABZPwJAXtLBY2vm8FqMyGAtNxncCJ65HdNKHFGNnE.tar.zst", sha256: "435499c7ffb4f357d2956e3bb2802a81264f6f2f50c896c9913fb86f7bc752bb" }),
	FetchLocked("roc-stable", roc_nightly("nightly-2026-10-23-18478ff")),
	FetchLocked("roc-docs", file("${automation}/roc-docs")),
	# The utility behind the shared release workflow, from a roc-automation tools release.
	FetchLocked("release-package", file("${automation}/release-package")),
	Environment("dev", [
		Tools(["roc-stable#roc-stable"]),
		# Every bundle the scripts depend on, including dependencies of
		# dependencies: `roc-stable deps scripts/check_all.roc` lists them.
		RocPackages([
			"https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
			"https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
		]),
		# Programs the scripts start.
		Expect(["gh", "git", "gzip", "kai", "roc", "sh", "shasum", "tar", "unzip"]),
	]),
	Environment("docs", [Tools(["roc-docs#roc-docs"]), Expect(["realpath", "sh"])]),
	# The shared release workflow runs this utility against the `roc` on PATH; a
	# maintainer runs the same task locally, such as `-- test-examples --update`.
	Environment("release", [Tools(["release-package#release-package"]), Expect(["roc", "git", "gh", "tar", "unzip", "zip", "chmod", "touch", "env"])]),
	Shell("default", [Use("dev")]),
	# Everything checked before the release workflow packages anything.
	Task("check", [Use("dev"), Run(["scripts/check_all.roc"])]),
	Task("release-package", [Use("release"), Run(["release-package"])]),
	# The reviewed SBOM composition for the bundle the release workflow built.
	Task("prepare-sbom", [Use("dev"), Run(["scripts/prepare_sbom.roc"])]),
	Task("docs", [Use("docs"), Run(["roc-docs", "build", "--workspace", ".", "--docs-directory", "docs", "--entrypoint", "index.adoc", "--pdf-filename", "weaver.pdf", "--site-url", "https://lukewilliamboswell.github.io/weaver/"])]),
	Task("docs-path", [Use("docs"), Run(["sh", "-c", "realpath \"$(command -v roc-docs)\""])]),
	# The parts of the manual that depend on what is released; see docs/contributing.adoc.
	Task("install-snippet", [Use("dev"), Run(["scripts/write_install_snippet.roc"])]),
	# The API reference of the GitHub Pages site: add it to the rendered manual,
	# or add it and preview the site locally.
	Task("site", [Use("dev"), Run(["scripts/build_site.roc"])]),
	Task("serve", [Use("dev"), Run(["scripts/serve_site.roc"])]),
	# Re-record assets/pretty-errors.svg from the deploy example's real output.
	Task("capture", [Use("dev"), Run(["scripts/capture_example.roc"])]),
	# What a pull request's release run checks first, on this machine.
	Workflow("ci", [RunTask("check", []), RunTask("release-package", ["test-examples"])]),
]

kaifile = Kaifile.new([Std.plugin(project), Sbom.plugin(project)])
