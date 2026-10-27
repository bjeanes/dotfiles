# Check how a repo is managed before writing to it

A `.git` directory does not mean the repo is driven by git. Many of my repos
are colocated Jujutsu (`jj`) repos, where jj owns the working copy and git is
just the backing store. Before running any git command that writes, check
which kind of repo it is. Inside a jj repo, `jj root` succeeds and a `.jj`
directory sits alongside `.git`.

When jj is in charge, use `jj` for anything that changes the working copy,
history, or refs. Read-only git (`git log`, `git show`, `git diff`) is fine.
Do not run mutating git commands -- `git stash`, `git checkout`, `git reset`,
`git add`, `git commit`, `git rebase`, `git merge`. jj auto-snapshots the
working copy into the working-copy change; these fight that and desync the
two views.

Do not assume the git command has a same-named jj equivalent, or guess at
flags -- look them up when you need them (`jj help`, `jj help -k`, the docs).

A colocated repo normally shows detached HEAD in `git status`. It looks like
a problem. However, it is the expected steady state. Leave it alone.

# What a commit is for

Every commit should be clear, atomic, and reviewable -- by me and by anyone
I work with. Each one holds a single logical change, whole and with nothing
else in it. It builds and works on its own. Its message says what changed and
why. A reviewer
should never have to untangle two changes from one commit, or piece one
change together from several.

Drawing those boundaries is the hard part. It gets harder the longer
unrelated work piles up together. So, cut a commit as soon as a unit is done,
before the next one starts on top of it.

A large change lands as a series of commits, each one reviewable on its own.
For example: refactor the dependencies first, then introduce the new
component, then tie it together. Each commit changes as little code as its
step needs (see `code.md`). Its message gives the reader the context they
need to review it (see `writing.md`).

These standards hold whoever makes the commit and however much autonomy they
have. That includes you under a go-ahead, a subagent, and proof-of-concept or
exploratory work.

# Committing

By default you are my pair. We work through each commit together. Never
commit without being told to. Not at the end of a task, not as a
convenience, not because the work looks finished. Leave changes in the
working copy and let me decide when they land.

But do not run past the natural commit boundaries either. When the work
spans several coherent, self-contained units, stop at the end of each one
rather than building the whole feature into a single undifferentiated pile.
Say what is done, what is next, and let me commit before continuing.

Some projects loosen this default in their own instructions. Others tighten
it. For that project, its instructions win. Wherever committing is allowed,
the rest of this file says how to do it.

## When I give the go-ahead

I may give the go-ahead for a line of work -- "commit as you go", or
agreeing to a plan of commits. Within that line of work, commit each unit
yourself as it is finished and checked, and keep going without waiting on
me. Afterwards, tell me what landed: each commit's change ID and subject.

That go-ahead is for that line of work only. It does not extend to the
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

I often work with `@` on top of a megamerge. That is a merge whose parents
are separate lines of work, each based on trunk, so that all of them are in
effect at once. `closest_merge(@)` finds it. When `@` is a megamerge or a
descendant of one, new work becomes a line of its own. That makes it another
parent of the megamerge, parallel to the rest. It doesn't go on top of the
merge, or into another parent's line. Commit it above the merge, then move it
under with
`jj stack <revs>` (or `jj stage` for everything above the merge, as one line).

If making it a parent would leave the megamerge conflicted, don't. Keep the
line separate, based on trunk in its own workspace. Then ask me whether to
merge it in and resolve the conflicts, or leave it apart.

## Keep everyone's work in view

The working copy often holds more than your own work, such as the other
parents of a megamerge or uncommitted changes in the working commit. I may be
using it at the same time. So may agents working in parallel.

When it holds other work in progress, don't `jj edit` a different commit or
otherwise move the working copy off `@`. That would pull the context out from
under whoever is using it. `jj edit` also checks out a tree without my
local-only files. The next snapshot then folds those files into whatever
commit `@` sits on. A snapshot can happen at any moment, even when I approve a
command.

Instead, make your changes at `@` and place them with
`jj squash --from @ --into <rev> <paths>`. It accepts paths and works into any
ancestor. When `@` holds edits bound for different revisions in the same file,
or in the same hunk, move them precisely with `jj hunk squash ID[:LINES]...
--into <rev>`. `jj hunk absorb --dry-run` suggests where each hunk belongs.
"Splitting mixed changes" below and the jj-surgeon skill cover the details.
Afterwards, check that `jj diff -r <rev> --name-only` shows no
`.claude/` paths. Also check that `jj op log` shows only the operations you
meant to run. Since I may be working in parallel, expect some operations that
aren't yours.

If you need a clean tree, use a separate workspace. You may need one when your
work conflicts with other lines, or sits close enough to them to muddy test
results or behaviour. You may also need one when a change needs an
intermediate tree that squashing can't express. Even then, keep your line
under the megamerge wherever conflicts allow. Everything in flight should be
visible together in the main working copy. For example, a web app I'm running
from it should have the changes from every parallel line available to use.

## `.claude/` and `CLAUDE.md`

Leave changes to `.claude/` and `CLAUDE.md` out of feature commits. Unless I
ask otherwise, they stay uncommitted. I often keep them local-only, in a
commit or series of their own that is one of the megamerge's parents. In some
repos they hold notes on the domain and research I've gathered, which you
need in scope.

So when your work has to live apart from my megamerge -- in a megamerge of
your own, or a separate line because of conflicts -- make your own working
merge that also includes the parents holding those changes, so they stay in
effect while you work.

The local-only files -- `CLAUDE.local.md`, `.claude/settings.local.json` --
are never committed at all, not even to that series. They should be ignored.
However, don't rely on that. Check they aren't in what you're committing.

## Never publish

Nothing is ever pushed, and no PR is opened, without me saying so for that
specific push. Until something leaves this machine, all of it can still be
reshaped. That is what makes the go-ahead safe.

## Subagents

A subagent may commit the same way, in its own `jj workspace`, but only for
a line of work I have agreed to directly. If the delegating agent decided to
hand the work off on its own, the subagent doesn't commit. Brief it on these
rules. It commits only in
its workspace, never pushes, and never uses `jj op restore`, which rewinds
the operation log every workspace shares. The delegating agent brings its
commits into the stack, reviews them as it would its own, and removes the
workspace afterwards.

Put workspaces outside the repo tree. A workspace inside it can fail to
check out. Removing one takes two steps. `jj workspace forget` leaves the
workspace's working-copy commit behind, so `jj abandon` that as well.

Always pass `--no-colocate` to `jj workspace add`, even where a skill
(such as jj-subagent-workspaces) gives the command without it. In a
colocated repo, jj otherwise also creates a git worktree for the new
workspace, which means writing under the main repo's `.git` directory. My
sandbox denies writes there, so creating the workspace fails every time.
The workspace doesn't need a git worktree, since jj alone drives it.

If the sandbox blocks a workspace path, don't retry somewhere else.
Name the directory and ask me for write access to it as a step of its own.
Then create the workspace once that's granted. I may only see a denied path
as a bare "unable to open a workspace" error, with no choice offered. If you
silently retry elsewhere, it looks to me like a refusal I never made.

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
