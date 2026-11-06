import Text

## The package's dependencies, as the compiler resolves them and as
## `Kaifile.roc` pins them.
##
## `Kaifile.roc` pins each bundle the header of `package/main.roc` names as a
## `FetchAll`, by the SHA-256 its release publishes, so each supplier's SBOM
## can be bound to the exact file. These functions let a script check that the
## two agree.
Dependencies := [].{

	## The bundle URLs `roc deps package/main.roc` lists, in its order. Only
	## direct dependencies are accepted: a nested entry means a dependency
	## has dependencies of its own, which the composition must review.
	resolved : Str -> Try(List(Str), [UnexpectedDepsOutput(Str), TransitiveDependency(Str)])
	resolved = |output|
		match Text.lines(output) {
			[root, .. as rest] if root.ends_with("[package]") =>
				rest.map_try(
					|line|
						if line.starts_with("├── ") or line.starts_with("└── ") {
							Ok(line.drop_prefix("├── ").drop_prefix("└── "))
						} else {
							Err(TransitiveDependency(line.trim().drop_prefix("│").trim().drop_prefix("├── ").drop_prefix("└── ")))
						},
				)
			_ => Err(UnexpectedDepsOutput(output))
		}

	## The URLs of the file sources `kai sbom pins` reports: the files
	## `Kaifile.roc` pins with `FetchAll` and no environment puts on PATH.
	locked : Str -> Try(List(Str), [UnexpectedPinsOutput(Str)])
	locked = |pins| {
		report : Try({ sources : Dict(Str, { provider : Str, ref : Str }) }, _)
		report = Json.parse(pins)
		match report {
			Ok({ sources }) => Ok(sources.to_list().keep_if(|(_, source)| source.provider == "file").map(|(_, source)| source.ref))
			Err(_) => Err(UnexpectedPinsOutput(pins))
		}
	}

	## Whether the resolved and the locked URLs name the same bundles, in any order.
	agree : List(Str), List(Str) -> Bool
	agree = |from_deps, from_lock| Text.sort(from_deps) == Text.sort(from_lock)
}

ansi = "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.13.3/Abc.tar.zst"

path = "https://github.com/roc-lang/path/releases/download/4.0.0/Def.tar.zst"

expect Dependencies.resolved("package/main.roc (/w/package/main.roc) [package]\n├── ${ansi}\n└── ${path}\n") == Ok([ansi, path])
expect Dependencies.resolved("package/main.roc (/w/package/main.roc) [package]\n") == Ok([])
expect Dependencies.resolved("package/main.roc [package]\n└── ${ansi}\n    └── ${path}\n") == Err(TransitiveDependency(path))
expect Dependencies.resolved("error: no such file\n").is_err()
expect Dependencies.locked("{\"format\":2,\"sources\":{\"roc-ansi\":{\"digest\":\"sha256:93\",\"name\":\"roc-ansi\",\"provider\":\"file\",\"ref\":\"${ansi}\",\"rev\":\"\"},\"nixpkgs\":{\"provider\":\"github\",\"ref\":\"github:NixOS/nixpkgs\"}},\"fetched\":[{\"name\":\"roc-stable\",\"urls\":[\"${path}x\"]}]}") == Ok([ansi])
expect Dependencies.locked("{\"format\":2,\"sources\":{},\"fetched\":[]}") == Ok([])
expect Dependencies.locked("kai: no Kaifile.roc").is_err()
expect Dependencies.agree([ansi, path], [path, ansi]) and !Dependencies.agree([ansi], [ansi, path])
