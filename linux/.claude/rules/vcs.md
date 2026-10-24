# Check how a repo is managed before writing to it

A `.git` directory does not mean the repo is driven by git. Many of my repos
are colocated Jujutsu (`jj`) repos, where jj owns the working copy and git is
just the backing store. Check before running any git command that writes:
`jj root` succeeds inside a jj repo, and a `.jj` directory sits alongside
`.git`.

When jj is in charge, use `jj` for anything that changes the working copy,
history, or refs. Read-only git (`git log`, `git show`, `git diff`) is fine.
Do not run mutating git commands -- `git stash`, `git checkout`, `git reset`,
`git add`, `git commit`, `git rebase`, `git merge`. jj auto-snapshots the
working copy into the working-copy change; these fight that and desync the
two views.

Do not assume the git command has a same-named jj equivalent, or guess at
flags -- look them up when you need them (`jj help`, `jj help -k`, the docs).

One thing worth knowing up front, since it looks like a problem and is not:
a colocated repo normally shows detached HEAD in `git status`. That is the
expected steady state. Leave it alone.

# What a commit is for

Every commit should be clear, atomic, and reviewable -- by me and by anyone
I work with. One logical change, whole and nothing else: it builds and
works on its own, and its message says what changed and why. A reviewer
should never have to untangle two changes from one commit, or piece one
change together from several.

Making those boundaries is the hard part, and it gets harder the longer
unrelated work piles up together. So the time to cut a commit is when a unit
is done, not after the next one has started on top of it.

# Committing

By default, never commit without being told to. Not at the end of a task,
not as a convenience, not because the work looks finished. Leave changes in
the working copy and let me decide when they land.

But do not run past the natural commit boundaries either. When the work
spans several coherent, self-contained units, stop at the end of each one
rather than building the whole feature into a single undifferentiated pile.
Say what is done, what is next, and let me commit before continuing.

## When I give the go-ahead

I may give the go-ahead for a line of work -- "commit as you go", or
agreeing to a plan of commits. Within that line of work, commit each unit
yourself as it is finished and checked, and keep going without waiting on
me. Afterwards, tell me what landed: each commit's change ID and subject.

That go-ahead is for that line of work only. It does not carry over to the
next task, or to anything that turns up along the way; ask again for those.
Still stop and ask when:

- a unit's boundary is unclear, or a change you need belongs in a commit
  you've already made;
- the plan has changed enough that what I agreed to no longer describes it;
- you would rewrite anything that isn't yours from this line of work --
  commits I made, my work in progress, anything immutable.

Rewriting your own commits from the same line of work to keep them clean is
fine and expected -- that is what jj is for.

Skills such as jj-surgeon cover how jj works; where they say to commit, these
rules decide whether you may.

## Working under a megamerge

I often work with `@` on top of a megamerge: a merge whose parents are
separate lines of work, each based on trunk, so all of them are in effect at
once. `closest_merge(@)` finds it. When `@` is a megamerge or a descendant of
one, new work becomes a line of its own -- another parent of the megamerge,
parallel to the rest -- not commits on top of the merge, and not part of
another parent's line. Commit it above the merge, then move it under with
`jj stack <revs>` (or `jj stage` for everything above the merge, as one line).

If making it a parent would leave the megamerge conflicted, don't. Keep the
line separate, based on trunk in its own workspace, and ask me whether to
merge it in and resolve the conflicts or leave it apart.

## `.claude/` and `CLAUDE.md`

Leave changes to `.claude/` and `CLAUDE.md` out of feature commits: unless I
ask otherwise, they stay uncommitted. I often keep them local-only, in a
commit or series of their own that is one of the megamerge's parents. In some
repos they hold notes on the domain and research I've gathered, which you
need in scope.

So when your work has to live apart from my megamerge -- in a megamerge of
your own, or a separate line because of conflicts -- make your own working
merge that also includes the parents holding those changes, so they stay in
effect while you work.

The local-only files -- `CLAUDE.local.md`, `.claude/settings.local.json` --
are never committed at all, not even to that series. They should be ignored,
but don't rely on that: check they aren't in what you're committing.

## Never publish

Nothing is ever pushed, and no PR is opened, without me saying so for that
specific push. This is what makes the go-ahead safe: until something leaves
this machine, all of it can still be reshaped.

## Subagents

A subagent may commit the same way, in its own `jj workspace`, but only for
a line of work I have agreed to directly -- not one the delegating agent
decided to hand off on its own. Brief it on these rules. It commits only in
its workspace, never pushes, and never uses `jj op restore`, which rewinds
the operation log every workspace shares. The delegating agent brings its
commits into the stack, reviews them as it would its own, and removes the
workspace afterwards.

## Splitting mixed changes

When one revision holds changes that belong in separate commits -- including
unrelated edits inside the same file or the same hunk -- don't settle for a
whole-file `jj split <paths>`, and don't combine them for convenience. Use
`jj hunk` (jj-hunk-tool) to select hunks, or line ranges within a hunk,
without an interactive editor:

- `jj hunk hunks [-r REV] [--file PATH]` lists hunks with IDs and line numbers.
- `jj hunk split ID[:LINES]... -m MSG` puts the selection in the first commit;
  `squash`, `restore` and `diffedit` mirror their jj counterparts the same way.
- `jj hunk absorb --dry-run` shows which ancestor each hunk would be folded into.

Hunk IDs change whenever the diff does, so list them again after every
rewrite.
