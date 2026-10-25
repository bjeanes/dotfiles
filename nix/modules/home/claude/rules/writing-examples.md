# Writing as me: examples

Read this before drafting anything that goes out under my name: commit messages,
PR descriptions, review comments, docs, and Slack or Notion drafts. The rules are
in `writing.md`. This file holds the evidence behind them.

Identifying names in the excerpts have been replaced with placeholders such as
`<service>` or `<colleague>`.

## How to use this file

The excerpts below are here to show how I reason and structure an explanation.
They are not a phrasebook. An agent given a handful of examples tends to reuse
their most distinctive phrases, and the result reads as parody. To avoid that:

- **Take the habit and leave the wording.** If a distinctive phrase from this
  file turns up verbatim in a draft, rewrite it. Plain connectives such as
  "However," and "Since…" are exempt; they are how I write everywhere.
- **The variety is the point.** The excerpts span 2020 to 2026. They include
  two-line commits, long ones, careful ones, and frustrated ones. No single
  excerpt is the template.
- **Match length to the change.** Most of my commits are a few sentences long.
  The long ones exist because the change needed explaining. Don't write a long
  one because the long examples are the most memorable.
- **Don't invent feelings or opinions for me.** "*hair pull*" and "🙄" are mine
  to use. Don't add frustration, humour or opinions I haven't expressed.

## Habits

Each habit is shown by several of the excerpts below.

1. **I write for the reader with the least context.** That could be someone
   non-technical, someone new to the company, or someone new to the industry
   who lacks the experience to connect cause to effect. I spell out that
   connection and the context around it. Context is everything. (A, C, F, H, M,
   O)
2. **The premise comes first.** I explain what is true about the system, or what
   went wrong, before saying what the change does. The reader should be able to
   predict the change by the time I describe it. (A, B, C, F, H)
3. **I own the reasoning and the mistakes.** I use the first person for what I
   did, found, suspect or got wrong. When I got something wrong I say how,
   without drama. (B, D, G) Needs and goals that belong to the work take "we" or
   a plain assertion instead. "We need to know…" and "It is important to
   know…" both work. "I want to know…" makes it sound like a whim.
4. **I say how sure I am.** "I think", "(I suspect)", "is believed to be", and
   "I'm not sure it will (because I still don't understand how it happens)".
   I state known facts flatly. (C, D, E, G, J)
5. **I show the evidence.** That means queries with their output, console
   sessions, before/after values, and links to the exact lines. I cite with
   `[1]` footnotes. (F, H)
6. **I name people and what they contributed.** That includes who spotted it,
   who I checked with, who will follow up, and who owns the next step. (I, L)
7. **I point at what's left.** That covers known gaps, follow-ups, and better
   approaches for later. I don't pretend the change is complete when it isn't.
   (A, C, H, I, K)
8. **I stress single words.** The mark goes on the word I would lean on when
   speaking. Most paragraphs have none. Some have one. Very few have two. I use
   `*asterisks*` where the text will be read as plain text, such as a commit
   message, and `_underscores_` elsewhere because they're easier to type. Older
   commits mix the two, so don't infer a rule from any single excerpt.

## Excerpts

These are trimmed in places, with typos left as written. Each one has a note on
what to take from it.

### A. Background first, then the trade-off (2026-05)

```text
chore: tweak lock and statement timeouts for migrations

The defaults in use up until now were copied from the Strong Migrations
README.

This makes them a bit more conservative, preferring explicit widening in
a migration file which needs it over a broad default.

To best understand the changes, it's important to understand the effect
that these timeout values have:

- `lock_timeout` affects only the time that a SQL statement can wait to
  acquire the lock, not how long it can hold the lock for.

  However, in the context of migrations, where the lock types in
  question can often be an exclusive table lock (even if held only very
  briefly), it is critical to know that Postgres will block _all_
  non-locking reads against the table awaiting an exclusive lock. This
  means that if we wait 30 seconds to acquire an exclusive lock, that's
  30 seconds where every SELECT against that table across all clients
  start hanging, which would be experienced as downtime for many tables
  (e.g. the `users` table).

[…]

Looking through Buildkite builds for recent deploys that included
migrations, we don't have one in recent history which took longer than
a minute or two.
```

Take from it: the reader gets the mental model before the decision. The one
emphasised word is the one that conveys the danger. The last paragraph grounds
the choice in something I checked.

### B. Owning a mistake (2025-01)

```text
performance fix: actually lock the reprocessing task (#<PR>)

When this outgoing code was first written, there was a single
`transaction` around the entire ActiveRecord scope enumeration, because
that was necessary for `FOR UPDATE SKIP LOCKED` locking to work.
However, later, I realised I didn't want such long-running transactions,
and so I mindlessly moved the `transaction` in one nesting level,
_inside_ the loop.

This resolved the long-running transactions but at the
obvious-but-somehow-overlooked cost of not actually locking the records.

[…]

I did spend some time trying to build the query conditions for this
myself, but it was getting hairy and dragging on. The added gem looks
pretty good, though I do have some ergonomic complaints about its API
because it does not take the `order` from the underlying
`scope.order_values`, but _could_.
```

Take from it: the history is told in order, the mistake is named plainly, and
the dependency is credited along with an honest reservation.

### C. A belief, labelled as one (2020-10)

```text
Refactor handling of invalid CSRF

[…]

This is because the high occurrence of these exceptions is believed to
be due to iOS unloading Safari from memory reasonably aggressively when
the user switches away from the app for a period of time. In that case,
the session-lifetime cookie is expunged and the user is no longer
logged in. As such, whether or not we check the CSRF token, the user
will be redirected to login and their form will be lost. This is
particularly common on the profile edit page (I suspect), because its
length and content probably sees more occurrences of app switching.

The issue of preserving large forms, such as the profile edit page will
have to be tackled separately, either client side or by persisting form
params in the DB to be restored after their session is re-created.
```

Take from it: "is believed to be", "(I suspect)" and "probably" each sit on a
claim I couldn't prove. The consequence that follows is stated flatly. The
problem left open gets its own paragraph.

### D. Uncertain fix, said so up front (2025-08)

```text
fix(ci): change the way branch diffs are calculated

This is a pretty subtle thing and hard to be sure it's totally right
until we run a few builds.

But basically, `git merge-base` will return _the most recent_ common
ancestor between the two refs [...]

I'm not positive that this version is totally right either, but the
theory here is that we list all commits that can be reached by the
feature branch but _not_ by `main` (`main..feature-x`) [...]

I think this is closer to what GitHub is doing behind the scenes to show
its diff in a PR, for instance.
```

### E. Short and tentative (2020-09)

```text
Fix bug where verification email is sent twice

I think `after_commit` might be running after save points too, so it was
creating two emails.

Since we want to switch to `deliver_later` anyway, this enqueues a
record to DB. So, if we are inside a transaction, the email will already
only be processed when and if that transaction is `COMMIT`ted. If we are
outside of a transaction, then it has _already_ been committed, so
sending is fine too.
```

Take from it: a short message that still gives its reasoning. Notice that
", so" does appear in my writing. It's the reflexive use I object to, where
"<assertion>, so <outcome>" stands in for an explanation.

### F. Evidence inline, footnoted links (2023-04)

```text
Event date ranges are exclusive of end boundary (#<PR>)

<service> stores the dates in Postgres as date ranges with _exclusive_ end
stops. So, a single-day event is actually stored as `[today, tomorrow)`
in the primary data store:

    <service>_production=> select lower_inc(dates), upper_inc(dates), count(*)
                        from <table> group by 1, 2;
        lower_inc | upper_inc | count
    -----------+-----------+--------
        f         | f         |     17
        t         | f         | 343410

These boundary values are sent to <service> as individual JSON fields[1] but
have been up until now incorrectly reconstructed as _inclusive_
ranges[2].

[…]

Changing this might cause some users to recognise a small drop in
impressions due to the events being effectively one day less, but overall
it should actually be fairer.

[1]: https://github.com/<org>/<service>/blob/7284c30/app/core/api/profile_presenter.rb#L190-L191
[2]: https://github.com/<org>/<service>/blob/8502cf4/app/models/profile/event.rb#L14-L16
```

Take from it: the evidence comes from production data and the links are pinned
to a SHA. The paragraph on user-visible impact covers who it affects and why
it's acceptable.

### G. Admitting I don't understand (2023-05, 2023-12)

```text
Disable CSRF checks on review

I don't understand why their is an uptick in this issue, especially
considering the fix in the previous commit didn't address it.

[…] Further, <colleague> claims this is happening even when she has opened only
a single tab.

*hair pull*
```

```text
Additionally, I'm hoping this might help with the ghost 2SL recovery
codes. I'm not sure it will (because I still don't understand how it
happens), but it seems plausible that if their active session was
revoked while on the 2SL management pages, that this could have caused
some undefined behaviour.
```

### H. Background as a setup for the point (2022-12)

```text
Fix dmetaphone for names with Unicode "fonts"

Unicode has multiple ways in the byte level to represent the same glyph
(sometimes with semantic difference, sometimes for anachronistic
reasons).

[… example and Wikipedia quote …]

This is all background to the important point that there is also a
_compatibility_ criteria when decomposing equivalent codepoints, that
allows for the transformation of _stylised_ characters (such as
ligatures, roman numerals, superscripts and Unicode "fonts") into their
simpler glyph.

[…]

Other than that, I also took the liberty of removing _all_ whitespace
instead of just the literal space character.
```

Take from it: when a teaching section runs long, I tell the reader where it's
heading. A drive-by change is called out as one instead of being slipped in.

### I. Incident fix with people and follow-ups (2026-06)

```text
fix: pull <feature> content from blog (#<PR>)

[…]

Fortunately, we cache the content in <service> and have been serving stale
articles from the cache in the interim, but the Redis-based cache is
volatile, so this could escalate to 5xx errors for all clients if not
addressed promptly.

With consultation from <colleague>, the blog tag to use is `<tag>`,
even though `<other tag>` tag also exists.

[…]

There is a lot of duplication between `<feature class>` in <service> and the
separate `BlogPosts` modules in each of <service> and <service>, which
would be useful to consolidate, […] but this will have to come later
(whether by me or another).
```

### J. A theory, stated as a theory (2023-04)

```text
Fix for my theory as to why CI is being flaky

The builds are failing with the `review` image build unable to find
`svelte-loader` dependency. It does start up `webpack` so dependencies
are definitely getting installed.

However, since these mounts have an `id` attribute, it's possible that
the same mount is being shared between `submit` and `review` builds.
```

### K. Small and to the point (2021-10, 2024-03, 2025-01)

```text
Simplify Zammad updating

* Remove filters on which changes should propagate (always update Zammad
  on model change)
* Merge the two classes and use `jobify!` for the enqueing
* Because it was hard to untangle change from WIP, this also fixes the
  bug where we update the email address of an existing user -- which
  shouldn't happen because it makes it harder for support to handle
  compromised accounts
```

```text
Build tickets search using related customer object

Searching with `customer.uuid` and `customer.email` will match ticket objects
instead of user objects in Zammad, which is more useful here.

Further, this changes from a pattern `email:foo OR email:bar OR email:baz` to
`email:(foo OR bar OR baz)` which will help keep the URL from exceeding the
maximum character limit.
```

```text
revert: Remove now-inert code for smearing event date lookahead (#<PR>)

[…] So this reverts the code because it was successful at moving us from a
90 day period to a 30 day period, but has now for a long time had no
effect, because `threshold < EVENT_ACTIVE_GOAL_THRESHOLD` is always true
now, so the goal value always gets returned.
```

### L. Shared conclusion, named owner (2026-05)

```text
The remaining rows in `zammad_tickets` point to tickets no longer in Zammad.
This was spot checked by me and @<colleague> and our shared conclusion is that
these were marked as spam. […] though it is apparent that some real tickets
have been deleted here, which <colleague> will talk to CX about.
```

### M. Readability for its own sake (2021-02)

```text
Clarity: reaper only loads discarded users

This is not a behaviour change but to know that, the reader has to
understand that SQL operators on a NULL value return a `NULL` value.
[…]

However, explicitly adding the extra `IS NOT NULL` check improves
readability and reviewability.
```

### N. Docs voice (a contributing guide)

```text
Ensure there is sufficient context in your Pull Request description that both
reviewers and future versions of ourselves who find their way to the PR via
`git blame` can understand what and why the change was made.

[…]

> Make `git blame` as relevant and useful for future VCS archaelogists.

Some people commit in an "snapshot" style, appending each change as make it,
while others `git rebase` and `git commit --amend` as they go to curate a set
of atomic changes that group relevant changes together. Both are valid, […]
```

### O. Written for a non-engineering audience (2026-03)

This was drafted to double as changelog copy.

```text
fix: VC cases not progressing when last action is VP reject (#<PR>)

[…]

Typically, VP is reviewed before AV anyway, so this obscured the issue and made
it rare, despite the gap.

However, it is still possible to make a decision on VP *after* the decision has
been made on AV, by either:

1. Opening both AV and VP in a tab but then acting on AV first; or
2. Rejecting VP, Accepting AV, awaiting re-submission, then rejecting the
   second VP.

   This probably accounted for a lot of the instances, but this has not been
   thoroughly analysed. In this case, it would have moved out of the queue for
   the first rejection, but got stuck in the queue upon the second rejection.
```

Take from it: it explains why the bug was rare before explaining how it still
happened. The scenarios are concrete steps a reviewer on the review team would
recognise. Only one claim is hedged. It's the one that hadn't been thoroughly
analysed.

## Claude-isms, rewritten

Most of the "before" examples are quoted from agent-drafted text in one of my
projects. The "quietly" and "deliberately not" examples are invented, since
those changes happen not to use either word. The "after" versions show one way to write each, not the
only way.

### "<assertion>, so <outcome>"

> It lists both buckets and writes to neither, so it is safe to run, interrupt
> and re-run.

> Since it only lists the two buckets and never writes to either, it is safe to
> interrupt and re-run at any point.

### Colon reveal

> Listings are not snapshots: S3 pages through a cursor, so an object uploaded
> or deleted while a prefix is being listed can appear on one side only.

> S3 listings page through a cursor instead of reading from a consistent
> snapshot. An object uploaded or deleted while we're part-way through a prefix
> may therefore show up on only one side.

> The database can't drive this: what is orphaned on the mirror is exactly what
> no longer has a row.

> We can't use the database to find orphans on the mirror. Being orphaned
> _means_ the object no longer has a row.

### "Not X but Y" for rhetorical effect

> Ordering the fetches so the mirror always runs ahead of the source would
> narrow that window but not close it, since any action is taken after the
> comparison.

> Fetching so that the mirror always runs ahead of the source would narrow that
> window. However, any action happens after the comparison, by which point
> either side may have changed again.

### ", and" bridging clauses (and a reflexive "rather than")

> The join is only correct if both sides ascend in byte order, so the Differ
> checks each side as it consumes it and raises OutOfOrder rather than produce
> a wrong comparison.

> The merge-join is only correct if both listings ascend in byte order. I
> expect both providers to return keys that way, but I haven't confirmed it for
> Hetzner. Since a wrong comparison could eventually lead to deleting a live
> object, the Differ checks the order of each side as it consumes it. It raises
> `OutOfOrder` on the first key out of place.

The rewrite also says how sure I am of the premise. Agent drafts tend to drop
that. Only say it when it's true.

### "Quietly"

> Discarded jobs were quietly leaving gaps in the mirror the whole time.

> When a mirror job exhausted its retries, GoodJob discarded it. Because
> nothing alerts on discards, the gaps went unnoticed until we compared the
> buckets.

### The wrong thing as the subject

> A failing shard is logged and skipped. A bucket that can't be listed at all
> stops the run before any shard starts.

> If a shard fails, it is logged and skipped and the run will be aborted early
> if a bucket can't be listed at all.

The "after" here is my own wording. The passive voice ("is logged") isn't the
problem. It's the choice of subject. Here a condition has been squeezed into a
noun phrase ("a failing shard") and a bucket has been made the thing that stops
the run.

The same habit shows up in other forms:

> How long a shard takes will decide how the eventual repair job resumes and
> which queue it runs on.

> We'll decide how the repair job resumes and which queue it runs on based on
> how long each shard takes to process.

A duration doesn't decide anything. We do. When the sentence's subject isn't
the thing doing the action, find who or what actually does it.

Don't overcorrect. A plain "That…" referring to the fact the previous sentence
just established is fine. "That means running something against the production
buckets" and "That is almost exactly three files per photo" can both stay. They
point at something already on the page. The pattern to avoid is a noun phrase
standing in for the real actor or for a condition.

### "I want" for a need the work has

> Before repairing the Hetzner mirror, I want to know how far it has actually
> drifted.

> Before repairing the Hetzner mirror, it is important to know how far it has
> actually drifted.

"We need to know…" works too. Keep "I" for what I did or believe: "I suspect
most of the drift dates from the outage".

### An intensifier on a negative

> The hedge sits on exactly the claim that wasn't verified.

> Only one claim is hedged. It's the one that hadn't been thoroughly analysed.

> This deliberately does not retry within a shard.

> This doesn't retry within a shard. A shard is small enough to re-run in full,
> and resuming part-way would need state we don't otherwise keep.

## What not to copy

- **Typos.** "their is", "shoudl", "logut", "archaelogists".
- **Run-on sentences.** I write some, as in excerpt C. Don't imitate them.
- **Commits from roughly August 2026 onward.** Many were drafted with an agent
  and show the patterns listed above. Don't treat them as examples of my
  writing.
- **Feature-list commits.** Earlier commits with "New Components:" or
  "Key Features:" headings and terse, uniform bullets were also agent-drafted.
- **Formatting inherited from Slack or Notion.** Curly apostrophes, unwrapped
  lines, and their exporters' emphasis style show up in text I pasted from
  those tools. They aren't choices I made.
