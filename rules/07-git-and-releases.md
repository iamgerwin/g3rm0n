# 7. Git & releases

## Branches

- `main` is always releasable. Don't push broken work to it.
- Do work on short-lived branches: `feat/<topic>`, `fix/<topic>`, `docs/<topic>`, `chore/<topic>`.
- Open a pull request into `main`. Squash or rebase; don't create merge commits.

## Commits

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`,
  `docs:`, `refactor:`, `test:`, `chore:`, with an optional scope, e.g. `feat(ai): add Mistral credits`.
- Write the subject in the imperative mood, at 72 characters or fewer, with no trailing period.
- The body explains **why** the change is needed, not what the diff already shows.
- Keep one logical change per commit, and make sure tests pass at every commit.
- The commit author is the person accountable for the change. Don't add generated-by
  footers, tool signatures or co-author trailers for tools.
- Never commit credentials, `.env` files, caches or personal config.

## Versioning

g3rm0n follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: incompatible changes to config keys, flags or the cache format.
- **MINOR**: new sections, providers, flags or setup options.
- **PATCH**: fixes and wording that keep all existing behavior.

The version lives in a single place: `G3_VERSION` in `lib/core.sh`.

## Releasing

1. Update `G3_VERSION` in `lib/core.sh`.
2. Move the `Unreleased` notes in `CHANGELOG.md` under the new version and date.
3. Run the full [testing](06-testing.md) checklist.
4. Commit with `chore(release): vX.Y.Z`.
5. Create an annotated tag: `git tag -a vX.Y.Z -m "g3rm0n vX.Y.Z"`.
6. Push the commit and the tag, then publish a GitHub release from the tag, using
   that version's changelog section as the notes.
7. Check the one-line installer against the new release in a clean `HOME`.
