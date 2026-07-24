<!-- Badger Addons — see CONTRIBUTING.md. Merging is human-only. -->

## What & why

<!-- One or two sentences. Link the work order / decision. -->

- Work order: WO-0xx-IJ
- Decision (if any): D-0xx-IJ

## Checklist

- [ ] On a correctly-prefixed branch (`<prefix>/WO-0xx-IJ-<slug>`), **not** `main`.
- [ ] `pnpm validate` passes locally (stylua · luacheck · busted).
- [ ] Specs added/updated for the change (colocated `*_spec.lua`).
- [ ] Docs updated — work order ticked; decision logged if durable; behavior delta noted.
- [ ] In-game behavior changes confirmed with a real `/reload` on the TBC Anniversary client.
