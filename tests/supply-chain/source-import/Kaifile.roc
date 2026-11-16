# The inputs of the source SBOM import regression: one source archive pinned
# by its published SHA-256 on both systems. See README.md.
app [kaifile] {
	pf: platform "https://github.com/thebrandonlucas/kai/releases/download/v0.0.12/G3CQ6Ed3h7vyvV4eDvwH1J8UqBv2wEtkb9jLJhFkU5ny.tar.zst",
	std: "https://github.com/thebrandonlucas/kai/releases/download/v0.0.12/std-6VuNBrdv6tT7ZAVD4bWGBYYwk1KJoXP7gCnFip5VSK11.tar.zst",
	sbom: "https://github.com/thebrandonlucas/kai/releases/download/v0.0.12/sbom-HzyZunZdK6VM3Ve3WK2cVtnFtRcTH6qUU6T65ZNG17TF.tar.zst",
}

import pf.Kaifile
import std.Config
import std.Std
import sbom.Sbom

project : List(Config.Setting)
project = [
	Name("fixture"),
	Systems(["x86_64-linux", "aarch64-linux"]),
	FetchAll("dep", { url: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.13.3/BioPdu7WjVhTB2j1HaomKMi8htxsuwqwr79GbXY5nAUf.tar.zst", sha256: "93750a9b9993e4e2996feac0ddd6f199b6f3fd9ba81154a74f09f47481e1e2ba" }),
]

kaifile = Kaifile.new([Std.plugin(project), Sbom.plugin(project)])
