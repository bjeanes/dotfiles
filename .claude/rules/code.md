# Consult before changing code

Consult me before changing code, and before any large change. Some projects
loosen this in their own instructions.

When I give you a brief, start the way plan mode would. Before changing
anything, play back your understanding of it. That means more than quoting me
back. Do the research first: read the code it touches and check what the brief
assumes. Then come back with:

- the goal as you understand it, in your own words;
- what you found that bears on it, especially anything that contradicts the
  brief or that I may not know;
- the questions I need to answer before you go ahead;
- what you propose to do, including how it splits into commits.

Wait until I've agreed before starting on the change.

# Small diffs

Every change is headed for review -- by me first, and by peers on a PR.
Reviewability is the constraint that outranks coverage.

- Prefer the minimal diff that does the job. Don't rewrite what you're passing
  through.
- Leave unrelated fixes, renames, reformatting, and drive-by cleanups alone.
  Mention them instead; I decide whether they become their own change.
- Touch as few files as the task allows, and keep each hunk about one thing.

# Code comments

Write code that answers the question a comment would have. Naming,
decomposition, and explicit types carry more than prose does, and they can't
drift.

Add a comment only when something is genuinely subtle, or when its importance is
easy to overlook -- a non-obvious invariant, a deliberate deviation, a workaround
with a reason. That bar means comments are occasional, not routine.

Whatever you do write must stand on its own:

- No references to our conversation, to the task, to what the code "used to" do,
  or to a change being recent ("now handles…", "as discussed", "moved from…"). A
  reader six months from now has none of that context.
- Match the surrounding file's comment density and voice.
- If a comment restates the line beneath it, delete the comment or fix the code.
- When a comment would explain _what_ something is, try a better name first.
- Skip header comments that restate the class or method name. A header earns its
  place by warning the reader off something they would otherwise break, such as
  "pages are fetched lazily; don't materialise a listing".
- To explain a list of values, make the literal multi-line and give each element
  a short trailing comment. Don't write a block above that repeats every value.
- Say a thing once, where it applies. A spec doesn't need to repeat reasoning
  that already sits beside the code under test.
- Since comments are prose written on my behalf, the Claude-isms in
  `writing.md` apply to them too.

For example, this was drafted first:

```ruby
# How a key compares between the source and the mirror:
#
#   :match          on both sides, same content
#   :missing        on the source only
#   :orphan         on the mirror only
#   :size_mismatch  on both, different sizes
#   :etag_mismatch  on both, same size, different content hash
KINDS = %i[match missing orphan size_mismatch etag_mismatch].freeze
DISCREPANCIES = (KINDS - [:match]).freeze

# Example keys kept per kind, for a human to inspect.
SAMPLE_SIZE = 5
```

And this is what landed:

```ruby
KINDS = [
  :match,         # on both, same content
  :missing,       # on the source only
  :orphan,        # on the mirror only
  :size_mismatch, # on both, different sizes
  :etag_mismatch  # on both, same size, different content hash
].freeze
DISCREPANCIES = (KINDS - [:match]).freeze

SAMPLES_PER_KIND = 5
```

The header restated the constant's name, and the list beneath it said every
value twice. Each value now carries its own note. `SAMPLE_SIZE` needed a
comment to say what it counted, but `SAMPLES_PER_KIND` says it without one.

Prefer suggesting commit message content over lengthy code comments unless
misunderstanding the code could have serious consequences. Allow `git blame` to
answer the questions which a comment may otherwise address.
