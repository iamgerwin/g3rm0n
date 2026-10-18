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

The version lives in `G3_VERSION` in `lib/core.sh`, and it is mirrored in
`CHANGELOG.md` and in the `--version` examples. `scripts/bump-version.sh` changes all
of them together; `tests/docs.sh` fails if they disagree. Pick the part to bump from
the `Unreleased` notes: anything under **Removed**, or a breaking **Changed** →
major; anything under **Added** → minor (while the version is `0.x`, a minor bump is
optional for small additions that change no existing behavior); otherwise patch.

## Releasing

1. Make sure every change since the last release has its entry under `## [Unreleased]`.
2. On the release branch, run `scripts/bump-version.sh patch|minor|major`. It cuts the
   dated section, updates the version everywhere and runs the drift check.
3. Run the full [testing](06-testing.md) checklist.
4. Commit with `chore(release): vX.Y.Z`, open the pull request and merge it once CI passes.
5. On `main`, create an annotated tag: `git tag -a vX.Y.Z -m "g3rm0n vX.Y.Z"`, and push it.
6. Publish a GitHub release from the tag, titled `g3rm0n vX.Y.Z`, using that version's
   CHANGELOG section as the notes.
7. Check the one-line installer against the new release in a clean `HOME`, on Linux
   and on macOS.
