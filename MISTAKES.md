# Mistakes log

Notes-to-self about errors made, so future sessions avoid repeating them.

## 2026-06-29 — `jj rebase -s <tip>` silently dropped intermediate commits

**What happened:** A concurrent commit (`38674f40`, "cross-platform static linkage")
had landed on `yolo@origin` while a long audit chain was building locally off an
older base (`eacde65d`):

```
eacde65d → 618549ca (head/tail removal) → f988bb41 (Phase 2) → d83344e7 (wave 1)
         → 5a37624b (3.1/3.2) → 6fbfbd90 (3.3)
```

To reconcile the divergence I ran `jj rebase -s 5a37624b -d 38674f40`. `-s` rebases
the named commit **and its descendants** — but NOT its ancestors. So only 3.1/3.2 and
3.3 moved onto the new base; the head/tail removal + Phase 2 + wave 1 commits were left
behind (orphaned) and vanished from `yolo`'s ancestry. I then pushed that incomplete
`yolo`, and only caught it because `src/tree_render.zig` still referenced `head_lines`
(code that a "completed" PLAN.md item claimed was deleted).

**Root cause:** Picked the rebase source as "my latest commit" instead of "the first
commit after the common ancestor (fork point)". With `-s`, the source must be the
*base* of the divergent run, not the tip.

**The fix / correct procedure:**
1. Find the real fork point: `jj log -r 'fork_point(A | B)'`.
2. Rebase from the FIRST commit after the fork point: `jj rebase -s <first> -d <newbase>`
   (this carries the whole run). Or just rebase the base of the stack.
3. Recover orphaned commits with `jj log -r 'all()'` + grep on descriptions — jj never
   deletes them; they're reachable by id and re-attachable with another `jj rebase`.
4. Rewriting already-pushed commits needs
   `--config 'revset-aliases."immutable_heads()"=none()'` (they're immutable once on a
   remote bookmark). Doing so here was correct because the pushed state was *wrong*.

**Cheap guard that caught it:** a PLAN.md "Done" claim that disagreed with the code
(`grep head_lines src/`). Cross-check "done" docs against the actual tree after any
history surgery — and after a rebase, diff the new tip against the pre-rebase tip to
confirm no commits were lost (`jj log -r '<oldbase>::<newtip>'`).
