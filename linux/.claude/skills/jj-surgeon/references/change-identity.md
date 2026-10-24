# Preserving change IDs

Use one change ID from creation until the change is deliberately abandoned,
squashed, or submitted to main. Commit hashes will change as content or parents
change. Keep the original change IDs in notes and task comments.

For ordinary fixes, edit the original or fold a fixup into it:

```bash
jj squash --from <fixup> --into <original> -m "Final description"
jj absorb --from <fixup>
```

Review the result and conflicts; absorb can leave ambiguous edits in the fixup.
When editing a change directly, finish with `jj new` to leave an empty working
copy. Replacing an original with a duplicate breaks cited IDs, leaves duplicate
subjects, and requires a swap step plus extra checks.

## Give the other worker a temporary base

Suppose worker B has work above originals A1..An, while worker A must edit those
originals in place. Coordinate the original IDs and ownership first. Worker B
makes a temporary copy of the base and moves B's work onto it:

```bash
jj duplicate '<A1>::<An>'
# Record the new IDs printed by duplicate as T1..Tn, paired with A1..An.
jj rebase -s <B-first> -d <Tn>
```

Worker A edits A1..An in place. Worker B can rewrite its own work on the temporary
base without depending on those ongoing edits. Once both workers have finished,
worker B returns to the edited originals:

```bash
jj rebase -s <B-first> -d <An>
jj log --no-pager -r 'conflicts()'
# Resolve and test B on the updated base; verify no retained work uses T1..Tn.
jj abandon '<T1>::<Tn>'
```

Only the temporary copies are abandoned. A1..An and B's retained changes keep
their IDs. Agree on who performs the handoff; do not rewrite another worker's
active changes. Integration onto the edited base can require conflict resolution
and retesting.

## Copy an edited duplicate back into the original

If copies D1..Dn were already polished, transfer their final trees into originals
A1..An, rather than replacing the originals. First record each original/copy ID
pair and each desired description. Check that both chains represent the same
intended changes and base; a whole-tree restore also copies unrelated base
content, so reconcile any intentional base differences before using this recipe.
Coordinate with workers whose descendants will rebase.

Work bottom-up, from A1/D1 to An/Dn:

```bash
jj restore --from <D1> --into <A1>
jj describe <A1> -m "Final description of first change"
jj restore --from <D2> --into <A2>
jj describe <A2> -m "Final description of second change"
# Repeat through An/Dn. Restore copies content, not the description.
jj diff --git --no-pager --from <Dn> --to <An>
jj log --no-pager -r 'conflicts()'
```

Each restore preserves the original change ID and automatically rebases its
descendants. Intermediate descendants can conflict while the chain is restored;
finish the mapped chain and resolve any remaining conflicts before testing.
The tip diff must be empty. Verify the original IDs still resolve, descriptions
are correct, and retained descendants still contain their intended work.

Move any retained work off the copies and move your working copy off them before
cleanup. Abandon only the mapped duplicate chain after verification:

```bash
jj new <retained-tip>
jj abandon '<D1>::<Dn>'
```

Do not include unrelated descendants in the abandon revset. Run the executable
scenarios with `python3 tests/skill_workflows.py` from the source repository.
