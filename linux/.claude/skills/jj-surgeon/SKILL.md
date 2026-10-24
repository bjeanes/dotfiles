---
name: jj-surgeon
description: Comprehensive guide for working with Jujutsu (jj) version control. Use whenever inspecting or modifying jj changes or commits, including managing, viewing, creating, editing, splitting, squashing, rebasing, reordering, and changing history — including hunk-level operations, bookmarks, conflict resolution, revsets, bisecting, and all standard jj workflows.
---

# Jujutsu (jj) Agent Guide

## Key concepts

**Working copy is always a commit.** The working directory is automatically
snapshotted into commit `@` at the start of every jj command. There is no
staging area. All file changes are immediately part of `@`.

**"Clean" means an empty `@`.** When `@` has no diff vs its parent, the working
copy is clean. You do NOT need to `jj abandon` an empty `@` — it is harmless
and jj creates a new empty `@` automatically after operations that consume it.
**Always finish your work with a clean `@`.** Use `jj commit -m "message"`
(not `jj describe`) when you're done with a change — `jj commit` finalizes `@`
and creates a new empty working copy on top. If you use `jj describe` instead,
`@` still contains your changes and you're still "editing" it. This is the jj
equivalent of leaving a dirty working copy in Git.

**Change IDs vs commit IDs.** Every commit has two identifiers:
- *Change ID* — stable across rewrites (rebase, amend, squash). Shown as
  reversed-hex letters (k-z). Use this to refer to changes you plan to rewrite.
- *Commit ID* — content hash (standard hex). Changes on every rewrite. Matches
  the Git SHA in colocated repos. Becomes permanent once immutable.

**Keep one change ID for the whole lifecycle.** Preserve the original ID until
that change is deliberately abandoned, squashed, or submitted to main. Edit,
rebase, restore into, or squash fixups into the original. Duplicate-and-replace
breaks references in notes, trackers and reviews, creates doubled subjects in the
log, and adds a swap step with extra checks. For concurrent workers or an already
edited duplicate, use the recipes in
[Preserving change IDs](references/change-identity.md).

**No branches, only bookmarks.** Bookmarks are named pointers to commits. They
do NOT advance automatically on new commits (unlike Git branches). They DO
follow when a commit is rewritten. See
[references/git-interop.md](references/git-interop.md).

**Editing history is safe — but watch for conflicts.** jj rewrites commits
freely and automatically rebases descendants. If a rebase causes overlapping
changes, jj records a conflict in the descendant commit and warns you.
Conflicts are data (not blocking states) but must be resolved before the code
compiles. See
[references/conflict-resolution.md](references/conflict-resolution.md).

**Operation log.** Every command records an operation in a single log that is
**shared by every workspace** on the repo — concurrent operations from
different workspaces are reconciled into one timeline. Rewinding that log —
`jj undo`, `jj redo`, `jj op restore` — mutates shared state: it acts on
whatever operation sits at the shared head, which may be another workspace's
(or a human's) work, not yours. In any repo another agent or person might
touch — the default for agent work — **do not rewind the op log; recover
forward instead** (`jj restore`, `jj abandon`, `jj revert`). See
[Operation-log safety](#operation-log-safety-in-shared-repos).

## Always pass these flags

```bash
# When viewing diffs:
jj diff --git --no-pager
jj show --git --no-pager @-
jj diff --git --no-pager -r <rev>
jj log --no-pager -p --git -r <revset>

# These prevent pager hangs and ensure machine-readable unified diff output.
```

## Hunk-level operations

Several jj commands (`split`, `squash`, `diffedit`, `restore`) can operate at
the hunk level, but only through an interactive diff editor — **which agents
must never use**. `jj-hunk-tool` provides non-interactive equivalents using
stable hunk IDs. These are shown alongside their native jj counterparts
throughout this guide.

### Listing hunks

```bash
jj-hunk-tool hunks                      # list hunks in @ with IDs and line numbers
jj-hunk-tool hunks -r <rev>             # from a specific revision
jj-hunk-tool hunks --file src/main.rs   # filter to one file
jj-hunk-tool hunks --compact            # brief preview (no line numbers)
```

### Hunk IDs

- 7-char hex strings derived from file path + hunk content
- Stable across runs as long as the diff hasn't changed
- Duplicates get `-2`, `-3` suffixes
- If not found, re-run `hunks` for fresh IDs
- Line ranges: `id:5-30` (1-based, from `hunks` output)
- Multiple ranges: `id:2-6,34-37`

### Generating patches

```bash
jj-hunk-tool patch <id1> <id2:1-10>             # unified diff for selected hunks
jj-hunk-tool patch <id>:5-30,40-50 -r <rev>     # with line ranges and revision
jj-hunk-tool patch --reverse <id>                # reverse patch
```

## Creating and describing changes

```bash
jj new                                  # new empty change on top of @
jj new <rev>                            # new change on top of <rev>
jj new <rev1> <rev2>                    # new merge commit
jj new -A <rev>                         # insert after <rev>, rebasing descendants
jj new -B <rev>                         # insert before <rev>
jj commit -m "message"                  # set description on @, create new empty @
jj describe -m "message"                # set/update description (default: @)
jj describe <rev> -m "message"          # describe a specific revision
jj edit <rev>                           # set <rev> as @ (edit a historical change)
```

After `jj edit <rev>`, any file changes you make modify `<rev>` directly and
all descendants are rebased. Check `jj log -r 'conflicts()'` afterward. When
done, use `jj new` to stop editing and create a fresh empty `@`.

## Viewing changes

```bash
jj status                               # working copy status
jj diff --git --no-pager                # working copy diff
jj diff --git --no-pager -r <rev>       # diff of specific revision
jj show --git --no-pager <rev>          # description + diff
jj log --no-pager                       # commit graph
jj log --no-pager -r '<revset>' -p --git  # graph with patches
jj file annotate <path>                 # blame (which change introduced each line)
```

## Splitting

```bash
jj split path/to/file -m "these files"           # split by file
jj-hunk-tool split <id1> <id2> -m "msg"          # split by hunk
jj-hunk-tool split <id>:1-11 -r <rev> -m "msg"   # hunk + line range from other rev
jj-hunk-tool split <id> -r <rev> -p              # parallel siblings
jj-hunk-tool split <id> -A <rev>                 # insert after
```

**Always pass `-m`** to `jj split` and `jj-hunk-tool split`. Without `-m`, jj
opens `$EDITOR` for each resulting commit.

**Do not use bare `jj split` (without file paths).** It opens an interactive
diff editor. Use `jj split path/to/file` for file-level splits or
`jj-hunk-tool split` for hunk-level splits.

Splitting rewrites the target revision, so all descendants are rebased. jj
will warn if this creates conflicts — resolve them before continuing. See
[references/conflict-resolution.md](references/conflict-resolution.md).

## Squashing and absorbing

```bash
jj squash -m "msg"                                # squash @ into parent
jj squash -r <rev> -m "msg"                       # squash <rev> into its parent
jj squash --from <src> --into <dst> -m "msg"      # move changes between revisions
jj-hunk-tool squash <id1> <id2> -m "msg"          # squash specific hunks into parent
jj-hunk-tool squash <id> --from <rev> --into <rev> -m "msg"
```

**Always pass `-m` to `jj squash`.** Without `-m`, jj opens `$EDITOR`.

**Warning:** `jj squash` rewrites the destination commit, causing all its
descendants to be rebased. jj will warn if this creates conflicts — resolve
them before continuing. See
[references/conflict-resolution.md](references/conflict-resolution.md).

### Absorbing

`jj absorb` auto-distributes changes from `@` into the correct mutable
ancestors by blame — extremely powerful for fixup workflows.

```bash
jj absorb                               # auto-distribute @ into ancestors
jj absorb --from <rev>                  # absorb from specific revision
jj-hunk-tool absorb                     # hunk-aware absorb (whole-hunk routing)
jj-hunk-tool absorb <id1> <id2>         # absorb specific hunks only
jj-hunk-tool absorb --dry-run           # preview routing plan
```

Always review with `jj op show -p --no-pager` afterward.

`jj-hunk-tool absorb` differs from `jj absorb`: it treats each hunk as an
atomic unit and routes based on deleted/modified line blame. Pure insertions
fall back to the most recent mutable ancestor that touched the same file. New
files stay in `@`. Ambiguous hunks (lines from multiple ancestors) stay in `@`
with candidates printed.

## Editing diffs in place

```bash
jj-hunk-tool diffedit <id1> <id2> -r <rev>  # keep only selected hunks in <rev>
```

**Do not use bare `jj diffedit`.** It opens an interactive diff editor. Use
`jj-hunk-tool diffedit` with explicit hunk IDs instead.

## Restoring (undoing changes)

```bash
jj restore <paths...>                   # restore files in @ from parent
jj restore --from <rev> <paths...>      # restore files from specific revision
jj restore -c <rev>                     # undo all changes introduced by <rev>
jj-hunk-tool restore <id1> <id2>        # undo specific hunks from @
jj-hunk-tool restore <id> -c <rev>      # undo specific hunks from <rev>
jj-hunk-tool restore <id> --from <rev> --into <rev>
```

## Rebasing and reordering

```bash
jj rebase -r <rev> -d <dest>            # move single commit onto dest
jj rebase -s <rev> -d <dest>            # move commit + descendants
jj rebase -b <rev> -d <dest>            # move whole branch
jj rebase -r <rev> -A <after>           # insert after (reorder)
jj rebase -r <rev> -B <before>          # insert before
jj rebase -s @ -d main                  # rebase current stack onto main
```

Rebasing can create conflicts if the new base has diverged. jj will warn if
this happens — resolve them before continuing. See
[references/conflict-resolution.md](references/conflict-resolution.md).

## Undoing operations

**Prefer forward-only recovery.** The safe way to back out a mistake is a *new*
operation that reaches the state you want — not rewinding the op log.

```bash
jj restore <paths...>                   # reset files in @ to their parent state
jj abandon <rev>                        # drop a revision, rebase descendants
jj revert -r <rev> -d @                 # create reverse-patch of <rev> on @
jj op log --no-pager -n 10              # view recent operation history (read-only)
jj --at-op=<op-id> restore -r @         # recover files from a past op without rewinding
```

### Operation-log safety in shared repos

**What the op log is.** Every jj command — commit, rebase, squash, bookmark
move, even the automatic working-copy snapshot — appends an entry to a single
operation log in `.jj/repo/`. That log is **shared by every workspace** on the
repo, not per-workspace; commands run concurrently in different workspaces
append to the *same* log and jj reconciles them into one timeline (see
[references/workspaces.md](references/workspaces.md)). Each entry records the
complete repo state: all bookmarks, all Git refs, and the `@` of *every*
workspace.

**Why rewinding it loses other people's work.** Because the log is one shared
timeline, "the last operation" is the last operation performed by *anyone* —
you, another agent in another workspace, or the human. Any command that moves
the op head backward acts on that shared head, so it can silently drop work a
different workspace did:

- **`jj undo` / `jj redo` are NOT safe here.** `jj undo` is `jj op revert @`,
  and `@` is the current op head — whatever ran most recently *across all
  workspaces*. If another workspace committed, rebased, or even just snapshotted
  since your last command, `jj undo` reverts *their* operation, not yours, and
  they lose it with no warning.
- **`jj op restore <op-id>` is worse.** It rewinds the entire shared state —
  bookmarks, commits, and every workspace's `@` — back to `<op-id>`, discarding
  everything any workspace did afterward.

These are only truly safe in a **solo repo** — one workspace, nobody else
touching it. For agent work that assumption almost never holds (subagent
workspaces, quipu fan-out, a human working alongside you), so **treat every
op-log rewind as unsafe by default.**

**Recover forward instead:**

- Back out content with a *new* operation: `jj restore`, `jj abandon`,
  `jj revert -r <rev> -d @`, or re-editing the commit directly.
- To pull files out of a past state without touching the timeline, read them at
  that op: `jj --at-op=<op-id> restore -r @` (or `jj --at-op=<op-id> file show`).
- If you must invert one specific *past* op, `jj op revert <op-id>` adds a new
  op on top rather than rewinding — but it still mutates shared history, so
  confirm no other workspace built on that op first.
- If you have already broken the working copy, **stop and tell the human** —
  leave the op log alone rather than trying to rewind your way out.

## Hidden commits

After a history rewrite (`abandon`, `squash`, `split`, `rebase`), the old
commits become **hidden**: they drop out of `jj log`, but they stay in the
store and remain addressable by commit ID.

### Verifying history rewrites

A hidden commit ID works fine as a `--from`/`--to` operand for `jj diff`. This
is the standard way to confirm a large rewrite preserved the tree:

```bash
jj diff --from <old-tip-commit-id> --to <new-tip> --summary
```

The summary shows exactly the intended delta — empty when the rewrite was
purely structural (reordering, re-describing, splitting without content
changes). Any unexpected paths mean the rewrite altered content it should have
left alone.

### Resurrecting hidden commits

Reading a hidden commit is safe; landing on top of one is not. `jj new <hidden>`
or `jj edit <hidden>` **resurrects** it. Visibility propagates to ancestors, so
its entire hidden ancestor chain becomes visible again. If those commits were
rewritten rather than merely abandoned, their change IDs now have visible
successors, and every affected change ID becomes **divergent**.

To recover, abandon the resurrected chain, scoping the revset so it covers only
the resurrected commits:

```bash
jj abandon 'trunk()..<resurrected-head>'
```

## Conflicts

```bash
jj log -r 'conflicts()'                # find commits with conflicts
jj resolve --list                       # list conflicted files in @
jj resolve --list -r <rev>             # list conflicted files in specific revision
```

Conflicts are first-class data — a commit can contain conflicts and still be
rebased, squashed, or pushed. **For agents, the most reliable resolution method
is reading the conflicted file and editing out the conflict markers directly.**
jj's conflict markers differ from Git's — see
[references/conflict-resolution.md](references/conflict-resolution.md) for the
format and resolution strategies.

## Revsets

Revsets select sets of commits. Used with `-r` on most commands.

### Symbols

| Symbol | Meaning |
|---|---|
| `@` | Working copy commit |
| `@-` | Parent of `@` (shorthand for `@-1`) |
| `@--` | Grandparent of `@` |
| `root()` | Root commit |
| `trunk()` | Head of default remote's default branch |
| `<change_id>` | Commit by change ID (or unique prefix) |
| `<bookmark>` | Commit at bookmark |

### Operators

| Syntax | Meaning |
|---|---|
| `x-` | Parents of x |
| `x+` | Children of x |
| `::x` | Ancestors of x (inclusive) |
| `x::` | Descendants of x (inclusive) |
| `x::y` | DAG range: ancestors of y that are descendants of x |
| `x..y` | Set difference: ancestors of y minus ancestors of x |
| `~x` | Complement |
| `x & y` | Intersection |
| `x \| y` | Union |
| `x ~ y` | Difference (x minus y) |

### Common patterns

```bash
trunk()..@             # changes on current stack not yet on trunk
@::                    # @ and all descendants
ancestors(@, 5)        # last 5 ancestors
mutable() & ancestors(@)  # mutable ancestors of @
description("fixup")   # commits with "fixup" in description
mine() & mutable()     # my mutable commits
conflicts()            # all commits with conflicts
```

For the complete function reference, string/date patterns, and workspace
symbols, see [references/revset-reference.md](references/revset-reference.md).

## Workflows

### Stacking changes

```bash
jj commit -m "feature part 1"           # finalize @, create new empty @
# ... work ...
jj commit -m "feature part 2"
jj log --no-pager -r 'trunk()..@'       # see the stack
```

### Blame-guided fixup

```bash
jj file annotate src/main.rs            # find which change touched each line
jj-hunk-tool hunks                      # list current hunks
jj-hunk-tool squash <id> --into <target> -m "fix bug"
```

### Discard specific hunks

```bash
jj-hunk-tool hunks                      # list hunks
jj-hunk-tool restore <id1> <id2>        # undo those hunks
```

### Auto-fixup with absorb

```bash
# Make fixes in working copy, then:
jj absorb                               # auto-distribute to correct ancestors
jj op show -p --no-pager                # review what happened

# Or hunk-aware absorb:
jj-hunk-tool absorb --dry-run           # preview routing
jj-hunk-tool absorb                     # execute
```

### Reorder commits in a stack

```bash
jj rebase -r <rev> -A <after>           # move <rev> after <after>
jj rebase -r <rev> -B <before>          # move <rev> before <before>
```

### Back out a mistake

```bash
# Make a NEW operation that reaches the desired state — do NOT rewind the op log.
jj restore <paths...>                   # reset files in @ to their parent
jj abandon <rev>                        # drop a bad revision
jj revert -r <rev> -d @                 # reverse-patch a committed change
jj op log --no-pager                    # inspect op history (read-only)
```

Do NOT `jj undo`, `jj redo`, or `jj op restore` in a repo any other workspace
or person might touch — they rewind the shared op log and can silently drop
others' work. See
[Operation-log safety](#operation-log-safety-in-shared-repos).

## Common pitfalls for agents

- **NEVER use `-i` / `--interactive` flags.** Commands like `jj split -i`,
  `jj squash -i`, `jj restore -i`, `jj-hunk-tool absorb -i`, etc. open an
  interactive diff editor or prompt that waits for terminal input. This will
  hang indefinitely. Use `jj-hunk-tool` with explicit hunk IDs instead.
- **NEVER use bare `jj split` (without file paths).** It opens a diff editor.
  Use `jj split path/to/file` for file-level or `jj-hunk-tool split` for
  hunk-level.
- **NEVER use bare `jj diffedit`.** It opens a diff editor. Use
  `jj-hunk-tool diffedit` with explicit hunk IDs.
- **NEVER rewind the shared op log.** `jj undo`, `jj redo`, and
  `jj op restore <op-id>` all move the op head backward over a log shared by
  every workspace. `jj undo` reverts whatever operation ran most recently
  *across all workspaces* — which may be another agent's or the human's, dropped
  silently. `jj op restore` rewinds every workspace's entire state. Recover
  forward instead (`jj restore`, `jj abandon`, `jj revert`, or
  `jj --at-op=<op-id> restore` for read-only file recovery). See
  [Operation-log safety](#operation-log-safety-in-shared-repos).
- **NEVER `jj new` or `jj edit` onto a hidden commit.** A rewritten commit stays
  addressable by commit ID, but landing on it resurrects it along with its whole
  hidden ancestor chain, and turns any rewritten change IDs divergent. Hidden
  commit IDs are safe only as read-only `jj diff` operands. See
  [Hidden commits](#hidden-commits).
- **Do NOT create empty commits as position markers.** If you're tracking
  progress across a stack — e.g. a "CI walk" checking each commit — resist the
  urge to `jj new -m "ci walk scratch"` (or similar) to mark where you are. An
  empty, descriptively-named commit clutters the stack, and these almost never
  get cleaned up. Use a **bookmark** for ephemeral position-tracking instead:
  `jj bookmark set ci-walk -r <rev>` moves a named pointer with no commit, and
  `jj bookmark delete ci-walk` removes it cleanly when done. See
  [references/git-interop.md](references/git-interop.md).
- Do NOT `jj abandon @` to "clean up" an empty working copy. It's normal.
- **Always leave `@` empty when you're done working.** Use `jj commit -m "msg"`
  to finalize a change — NOT `jj describe`, which leaves your changes in `@`.
- Do NOT use `git` commands in a jj repo. Always use `jj`.
- Always pass `--git --no-pager` when viewing diffs.
- Always pass `--no-pager` to `jj log`, `jj op log`, `jj bookmark list`.
- **Always pass `-m "message"` to `jj commit`, `jj describe`, `jj squash`,
  `jj split`, and any other command that sets a commit message** — unless the
  user explicitly asks to write the message in their editor.
- `jj diff` with no `-r` shows `@` vs parent. Use `-r <rev>` for other revisions.
- After `jj commit -m "msg"`, the described change is `@-` (the parent). `@` is
  the new empty working copy.
- Immutable commits (on trunk, tags, remote bookmarks) cannot be rewritten.
  Use `mutable()` revset to find what you can edit.
- `jj squash` without args squashes `@` into `@-`. With `--from`/`--into` you
  can squash between any two mutable commits.
- After any history rewrite, jj will warn if conflicts were created. Resolve
  them immediately — cascading conflicts are much harder to fix. See
  [references/conflict-resolution.md](references/conflict-resolution.md).
  Use `jj log -r 'conflicts()'` if you need to find all conflicted commits.
- **jj does not rename-trace across history rewrites.** Amending or squashing
  into a file at its old path, below a descendant that renames it (e.g. a crate
  or module rename), causes the rebase of the rename commit to conflict. Resolve
  by applying your change to the new path — re-applying the rename commit's
  in-file transformations such as rewritten imports — then removing the old path.
  See [references/conflict-resolution.md](references/conflict-resolution.md).

## Reference docs

- [Revsets](references/revset-reference.md) — full function list, string/date patterns
- [Conflict resolution](references/conflict-resolution.md) — marker format, reading guide, strategies
- [Git interop](references/git-interop.md) — bookmarks, pushing, remotes, colocated repos
- [Workspaces](references/workspaces.md) — multiple working copies, sparse checkouts
- [Templates](references/template-reference.md) — custom log/show output
- [Bisect](references/bisect.md) — binary search for regressions with `jj bisect run`
