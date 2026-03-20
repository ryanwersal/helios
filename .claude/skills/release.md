---
name: release
description: Generate curated release notes, create an annotated tag, and push to trigger CI.
user_invocable: true
argument: version tag (e.g. v0.2.0)
---

# Release

Create a release for the Helios project.

## Inputs

The user provides a version tag as the argument (e.g. `v0.2.0`). If no argument is provided, ask for the version tag.

## Steps

1. **Validate the tag** — ensure it starts with `v` and doesn't already exist locally or on the remote.

2. **Find the previous tag** — use `git tag --sort=-v:refname` to find the most recent existing tag.

3. **Collect commits** — run `git log <prev_tag>..HEAD --format="- %s"` to get all commit subjects since the last tag.

4. **Generate release notes** — curate the raw commit list into clean, grouped release notes. Group by category based on commit message content:
   - **Added** — new features, new providers, new capabilities
   - **Changed** — enhancements, refactors, updates to existing behavior
   - **Fixed** — bug fixes
   - **Infrastructure** — CI, build, tooling, dependency changes

   Omit empty categories. Rewrite commit messages for clarity when needed — these are user-facing notes. Drop noise commits (formatting-only, typo fixes) unless they're the only changes.

5. **Present the notes** — show the generated release notes to the user and ask for approval. The user may request edits.

6. **Create an annotated tag** — once approved, create the tag with the release notes as the annotation message:
   ```
   git tag -a <tag> -m "<release notes>"
   ```

7. **Push the tag** — push only the tag to origin:
   ```
   git push origin <tag>
   ```

This triggers the release workflow in `.github/workflows/release.yml`, which builds the app and creates a GitHub release using the tag annotation as the release body.
