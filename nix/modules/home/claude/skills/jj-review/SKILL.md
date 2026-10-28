---
name: jj-review
description: Review a range of jj changes one at a time in revdiff, with each change's description shown as a COMMIT_MSG file, then act on the annotations by tidying the changes they belong to. Use when asked to "review my changes/stack/commits", "jj review", "review each commit", or to review a revset change by change.
---

# Reviewing jj changes one at a time

The loop opens each change in the range in revdiff, oldest first, and opens the
next one as soon as the reviewer closes the last. Each review shows that
change's own diff, plus a `COMMIT_MSG` file holding its description. The
reviewer can comment on lines, on whole files, and on the commit message.

## 1. Pick the range

Use the revset the user gives. Without one, use the current stack:

```
trunk()..@- ~ empty() ~ merges()
```

Under a megamerge, that covers every line of work beneath it. List the
changes in the range (`jj log -r '<revset>'`) and say how many there are
before opening anything. Ask before opening more than about ten.

## 2. Run the loop

Make an output directory first, in its own call:

```bash
mktemp -d "$TMPDIR/jj-review-XXXXXX"
```

Then run the loop with that path written out literally, as a plain command
with no variables, substitutions, pipes or redirects. The sandbox only lets
the loop open revdiff's overlay when every part of the command matches its
exclusion.

```bash
@out@/scripts/jj-review-loop.sh '<revset>' /path/printed/above
```

Give it the longest timeout allowed. It blocks until the reviewer has been
through every change. If it is moved to the background, wait for the
notification and don't start it again.

The reviewer steers the loop with an annotation that reads just `stop`, to
end it early, or `prev`, to go back to the previous change. The loop removes
those from its output.

## 3. Read the annotations

The output has one `# <n>-<change>` heading per change with annotations,
followed by revdiff's own blocks:

```
# 01-ukpyvmlo

## COMMIT_MSG (file-level)
...

## COMMIT_MSG:7 (+)
...

## nix/modules/home/claude/default.nix:17 (+)
...
```

- The heading names the change each annotation belongs to.
- A change the reviewer went back to has its annotations from every visit,
  oldest first. A later one may revise or withdraw an earlier one.
- `COMMIT_MSG` opens with 5 header lines (Change, Commit, Parent, Author and a
  blank line). `COMMIT_MSG:N` is line `N - 5` of the description. A
  file-level note on `COMMIT_MSG` is about the change as a whole.
- `(+)` lines are in the change's own tree. `(-)` lines are in its parent's.
  `jj file show -r <change> <path>` shows the right side.
- revdiff can only anchor to one line. When the text names a range ("through
  line 52", "this block", "the hunk"), take the range it names.
- Decide whether an annotation is a question or a request by what it asks.
  Answer questions in the conversation, without editing anything.

## 4. Plan, then apply

Present a plan covering every annotation before changing anything, and wait
for approval.

The default is to tidy the change the annotation is on. Fold code fixes into
it, and rewrite its description for anything on `COMMIT_MSG`. Make edits at
`@` and move them with `jj squash --from @ --into <change> <paths>`, or with
`jj hunk squash` when `@` holds other work in the same file. Use
`jj describe -r <change>` for descriptions. The jj-surgeon skill and the
global vcs rules cover the details.

Some annotations change that:

- If an annotation says to make a new commit, or to squash somewhere else, do
  that.
- If the change is immutable (`jj log -r '<change> & immutable()'` prints
  it), say so. Propose new commits for the fix instead.
- If a fix is substantial, or shifts what the change means, propose a commit
  plan that suits it, such as a new commit or a split. Propose only.

Delegate a fix to a subagent only when its scope is clear, briefed as the
global vcs rules describe.

Afterwards, offer to run the loop again over just the changes that were
rewritten.
