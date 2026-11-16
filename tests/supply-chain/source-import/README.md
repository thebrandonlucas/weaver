# Source package SBOM import regression

These inert inputs preserve the actual generated roc-ansi candidate SBOM: a
valid source supplier that a native inventory must accept. They do not assert
that 0.13.3 has been published.

Run the regression from the repository root with Kai's sbom plugin (no
compiler or Nix needed):

```sh
python3 tests/supply-chain/source-import/check.py
```

It checks source and both Linux native inventories, the conservative defaults
added while normalizing the unchanged v1 composition, and each refusal below.
It preserves the supplier's document digest, source identity and incomplete
coverage. No unknown fact becomes a standard completeness claim.

For individual inspections:

```sh
fixture=tests/supply-chain/source-import
for target in source x86_64-linux aarch64-linux; do
  kai -f "$fixture/Kaifile.roc" sbom inspect --composition "$fixture/composition.json" --output "$target-inventory.json" -- "$target"
done
```

All three must succeed and preserve the supplier's source identity.
`Kaifile.roc` pins the supplied source archive's SHA-256 with `FetchAll`;
composition.json embeds the supplier document and binds its subject filename,
digest and version to that pin. No supplier artifact is fetched or executed.
The compiler/native dependency closure of a downstream executable is a
separate responsibility from importing a source archive's graph.

Changing imported_documents[0].sha256 must reject with `imported SBOM content
digest mismatch`. Changing imported_documents[0].subject.sha256 or .version must
reject with `import subject filename/version/SHA256 mismatch`. Relabelling the
source import's target as native must reject with `imported document subject
target mismatch`.
