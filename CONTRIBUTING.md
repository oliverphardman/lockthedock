# Contributing

Thanks for your help! Lock The Dock is a macOS menu bar app, written in Swift, that keeps the Dock on one display.

## Setup

You need a Mac with Xcode 27, which is what CI uses. There are no other dependencies.

1. Clone the repo.
2. Enable the Git hooks (required once per clone):

   ```sh
   git config core.hooksPath .githooks
   ```

3. Open the project:

   ```sh
   open LockTheDock.xcodeproj
   ```

### Signing and Accessibility access

The app needs Accessibility access (System Settings > Privacy & Security > Accessibility).

The project is ad-hoc signed by default, so macOS can lose that access when you rebuild. To keep it, choose your team and a development certificate in the target's **Signing & Capabilities** tab. This changes the project file, so don't commit your signing settings.

If the app doesn't see its permission, quit it, run the command below, then reopen it and grant access again:

```sh
tccutil reset Accessibility local.lockthedock
```

Quit other Dock lockers, including any installed copy of Lock The Dock, while testing.

## Project layout

| Path | Contents |
| --- | --- |
| `src/` | Swift source |
| `tests/` | Tests (Swift Testing) |
| `resources/` | `Info.plist`, string catalog and app icon |
| `resources/artwork/` | Master copies of the icon artwork |
| `LockTheDock.xcodeproj/` | Xcode project |
| `.githooks/` | Pre-commit hook |
| `.github/` | Workflows, Dependabot, and issue and pull request templates |

## Building and testing

In Xcode, press **⌘R** to run and **⌘U** to test. From the command line:

```sh
xcodebuild test -project LockTheDock.xcodeproj -scheme LockTheDock -destination 'platform=macOS' -derivedDataPath build
```

To build a release copy, which appears in `build/Build/Products/Release/`:

```sh
xcodebuild build -project LockTheDock.xcodeproj -scheme LockTheDock -configuration Release -derivedDataPath build
```

The tests cover the screen edge calculations. They don't cover the event tap or the menu, so check changes to those by running the app, and say what you checked in the pull request.

## Code style

[swift-format](https://github.com/swiftlang/swift-format), which ships with Xcode, handles formatting and linting. Its rules are in `.swift-format`.

```sh
# Format
xcrun swift-format format --in-place --recursive src tests

# Check, as CI does
xcrun swift-format lint --strict --recursive src tests
```

`.editorconfig` covers other file types. If you use VS Code, install the recommended extensions to format Swift on save.

## Localisation

Wrap text shown to users in `String(localized:comment:)`, with a comment that helps translators. Add it to `resources/Localizable.xcstrings`, which you can also use to add or edit translations in Xcode. Keep the app's name, Lock The Dock, unchanged in translations.

## App icon

Edit `resources/AppIcon.icon` in Icon Composer, which comes with Xcode. The artwork inside it is a copy, so make changes to the shapes in `resources/artwork/` and import them again.

## Workflow

1. Branch from `main`: `git switch -c <type>/<short-description>`.
2. Make your change. Keep pull requests small and focused.
3. Commit using [Conventional Commits](https://www.conventionalcommits.org).
4. Push and open a pull request. Give it a Conventional Commits title and fill in the template.
5. Wait for CI to pass and for review before merging.

## Commit messages

Format: `type(scope): summary`, for example `fix(menu): show disconnected displays`. The scope is optional.

| Type | Use for | In changelog |
| --- | --- | --- |
| `feat` | New functionality | Features |
| `fix` | Bug fixes | Fixes |
| `perf` | Performance improvements | Performance |
| `revert` | Reverting a change | Reverts |
| `deps` | Dependency updates | Dependencies |
| `refactor`, `docs`, `test`, `ci`, `chore` | Everything else | Hidden |

Mark breaking changes with `!` after the type (`feat!: ...`) or a `BREAKING CHANGE:` footer.

## Checks

### Pre-commit hook

| Check | Runs when |
| --- | --- |
| Whitespace errors and conflict markers | Every commit |
| `swift-format` lint | Swift files are staged |
| Property list and project file validity | Those files are staged |
| JSON validity | The string catalog, icon settings, formatter config or release config are staged |
| Tests | Source, tests, resources or the project change |

File checks read the staged content. Tests build your working tree, including unstaged changes, and write their log to `build/pre-commit-tests.log`.

Fix failures rather than bypassing the hook with `--no-verify`.

### Continuous integration

The workflows are in `.github/workflows/`.

| Workflow | Runs | Purpose |
| --- | --- | --- |
| `ci.yml` | On pull requests | Runs `swift-format`, validates the property list, project file and string catalog, tests and makes a Release build |
| `codeql.yml` | On pushes and pull requests to `main`, weekly, or manually | Scans the Swift code and workflows with CodeQL. Swift is built with Xcode 26, which CodeQL supports |
| `release-please.yml` | On pushes to `main`, or manually | Opens release pull requests and creates releases |
| `cd.yml` | On published releases, or manually | Tests and builds the app, and attaches it to the release |

Dependabot checks for GitHub Actions updates weekly. Actions are pinned to commit SHAs, with the version in a comment; keep that format when adding one.

## Releases

[release-please](https://github.com/googleapis/release-please) opens a release pull request from the commits on `main`, updating `CHANGELOG.md`. Don't edit that file by hand. Merging the pull request creates a tagged GitHub release, and `cd.yml` builds the app and attaches it. The version comes from the tag.

To rebuild an existing release, run `cd.yml` manually with its tag.

Both release workflows use a GitHub App, configured with the `RELEASE_PLEASE_APP_CLIENT_ID` variable and the `RELEASE_PLEASE_APP_PRIVATE_KEY` secret. `cd.yml` can't upload without it.

Release builds are ad-hoc signed and not notarised.

## Security

Do not report vulnerabilities in public issues. See [SECURITY.md](SECURITY.md).

## Conduct

By participating you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
