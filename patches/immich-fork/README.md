# Immich fork patch series

Downstream patches for the `lunatickochiya/immich` fork, exported as a
`git format-patch` series so they can be replayed on a newer upstream Immich
checkout or turned into an upstream PR.

- **Base commit:** `d474ec966` (`v3.3.0-rc.0` era, upstream `main` on 2026-10-24)
- **Series tip:** `patch-series` branch, tree-identical to `5de6bdea0` on `main`
- **Patch format:** `git format-patch` (works with `git am --3way`)
- **Verified on:** upstream `256eb55db` (2026-10-25, includes the machine-learning
  and pillow dependency updates) — 0001–0004 apply with `git am --3way` without
  conflicts. The fork `main` merge `a78c1dcf1` already contains these patches.

## Patch list

| #    | File                                                              | Area                                                           | Upstream PR?                |
| ---- | ----------------------------------------------------------------- | -------------------------------------------------------------- | --------------------------- |
| 0001 | `0001-fix-mobile-hash-assets-without-ACCESS_MEDIA_LOCATION.patch` | Android native hashing fallback                                | ✅ yes                      |
| 0002 | `0002-feat-server-configurable-library-checksums-and-rehas.patch` | server config, import checksums, upload dedupe, rehash job/API | ✅ yes                      |
| 0003 | `0003-chore-open-api-regenerate-spec-and-TypeScript-SDK.patch`    | generated OpenAPI spec + TypeScript SDK                        | ✅ yes (usually regenerate) |
| 0004 | `0004-feat-web-expose-checksum-settings-and-recompute-acti.patch` | admin web UI, i18n (en/zh_Hans), e2e fixture                   | ✅ yes                      |
| 0005 | `0005-ci-keep-only-Docker-and-Release-workflows-for-the-fo.patch` | fork-only CI rewrite (deletes 26 upstream workflows)           | ❌ **fork only**            |

Convenience bundles:

- `upstream-candidate.patch` — 0001–0004 combined, no CI changes. Use this to
  prepare a PR against upstream.
- `immich-fork-all.patch` — everything, including the fork-only CI rewrite.

## Apply

### On a newer Immich checkout (recommended: `git am`)

```bash
git checkout -b fork-patches <new-base>
/path/to/patches/immich-fork/apply.sh /path/to/immich
```

The script applies 0001–0005 in order with `git am --3way` and stops on the
first conflict. To keep the CI patch out of an upstream PR:

```bash
/path/to/patches/immich-fork/apply.sh --no-ci /path/to/immich
```

To apply everything as uncommitted changes instead of commits:

```bash
/path/to/patches/immich-fork/apply.sh --apply /path/to/immich
```

Or do it manually:

```bash
git am --3way /path/to/patches/immich-fork/0001-*.patch
git am --3way /path/to/patches/immich-fork/0002-*.patch
git am --3way /path/to/patches/immich-fork/0003-*.patch
git am --3way /path/to/patches/immich-fork/0004-*.patch
# skip 0005 for upstream
```

One-shot, no commits:

```bash
git apply --3way /path/to/patches/immich-fork/immich-fork-all.patch
```

## After resolving conflicts

### Regenerate the OpenAPI spec and TypeScript SDK

Patch 0003 is generated output. If `server/src/dtos/config.dto.ts`,
`server/src/dtos/library.dto.ts`, `server/src/controllers/library.controller.ts`
or `server/src/enum.ts` conflicted, do **not** hand-merge patch 0003 — drop it
and regenerate:

```bash
corepack pnpm --filter immich build
(cd server && node dist/bin/sync-open-api.js)
corepack pnpm dlx oazapfts@7.5.0 \
  --optimistic --argumentStyle=object --useEnumType --allSchemas \
  open-api/immich-openapi-specs.json packages/sdk/src/fetch-client.ts
corepack pnpm --filter @immich/sdk build
```

`sync-open-api.js` does not need a database or Redis.

### i18n

Patch 0004 adds keys under the `admin` object in `i18n/en.json` and
`i18n/zh_Hans.json`. Keys are sorted by prettier:

```bash
corepack pnpm exec prettier --write i18n/en.json i18n/zh_Hans.json
```

If upstream renamed the admin settings page, only the Svelte file and these
keys need adjustment:

```text
admin.checksum_content_sha1
admin.checksum_path_sha1
admin.library_checksum_settings
admin.library_checksum_settings_description
admin.library_external_checksum
admin.library_external_checksum_description
admin.library_upload_checksum
admin.library_upload_checksum_description
admin.library_dedupe_uploads
admin.library_dedupe_uploads_description
admin.recompute_checksums
admin.recompute_checksums_description
admin.recompute_checksums_queued
admin.recompute_checksums_unsaved
admin.recompute_external_checksums
admin.recompute_external_checksums_prompt
admin.recompute_upload_checksums
admin.recompute_upload_checksums_prompt
```

## What each patch does

### 0001 — Android hash fallback

`mobile/android/app/src/main/kotlin/app/alextran/immich/sync/MessagesImplBase.kt`

- Primary path still opens `MediaStore.setRequireOriginal(uri)`.
- On `SecurityException` (typically `ACCESS_MEDIA_LOCATION` missing on
  Android 14+ OEM ROMs), fall back to the asset's `MediaStore.MediaColumns.DATA`
  file path and hash that stream.
- The uploader (`originFile`) uses the same file path, so the checksum matches
  the uploaded bytes.
- No Dart/UI change is required; the app no longer needs ADB-granted
  `ACCESS_MEDIA_LOCATION` for backup to proceed.

### 0002 — Server checksums

Key files:

- `server/src/enum.ts` — `ChecksumAlgorithmSchema`, `ChecksumRehashTarget`,
  `JobName.LibraryRehash`
- `server/src/dtos/config.dto.ts` — `library.checksum.external` and
  `library.checksum.dedupeUploadsAgainstLibraries`, defaults
  `sha1-path` / `true`
- `server/src/services/library.service.ts` — external import hashing,
  batch duplicate filtering, concurrent-conflict retry, rehash job,
  `queueRecomputeChecksums`
- `server/src/services/asset-media.service.ts` — upload de-duplication against
  external libraries (normal uploads only, not shared links)
- `server/src/repositories/asset.repository.ts` — checksum lookup/stream/update
  helpers
- `server/src/dtos/library.dto.ts` + `server/src/controllers/library.controller.ts`
  — `POST /libraries/recompute-checksums`
- `server/src/types.ts`, `server/src/utils/database.ts` — job payload and
  library checksum constraint handling
- tests/mocks updated accordingly

Behavior notes:

- `sha1-path` is still the default for external libraries (upstream behavior).
- Content mode (`sha1`) de-duplicates identical content **inside one external
  library**. This follows the existing unique index
  `(ownerId, libraryId, checksum)`; the importer skips duplicates instead of
  failing the batch.
- Uploads always use content `sha1`.
- `dedupeUploadsAgainstLibraries` only compares against external assets that
  already have a content checksum and are not offline/deleted.
- Changing the external algorithm does **not** rewrite existing rows; use the
  recompute action.

### 0003 — OpenAPI + SDK

Generated from the 0002 server changes. Regenerate rather than merge if
upstream moved the DTOs.

### 0004 — Web UI + i18n + e2e

`web/src/routes/admin/system-settings/LibrarySettings.svelte` adds a
**Checksums** accordion:

- external library algorithm select
- fixed content SHA-1 upload checksum (read-only)
- upload de-duplication switch
- recompute buttons (disabled while settings are unsaved)

### 0005 — Fork-only CI

Replaces all `.github/workflows/*` with:

- `docker.yml` — builds `immich-server` + `immich-machine-learning` (cpu and
  `-rknn`) for `linux/arm64` by default and pushes to `ghcr.io/<owner>`;
  manual dispatch can add amd64.
- `release.yml` — builds the Android APK with mise/Flutter and creates a GitHub
  release.

**Do not send this patch upstream.** It deletes project maintenance workflows
(tests, CodeQL, docs, release automation, etc.).

## Validation used on the fork

```bash
corepack pnpm --filter immich check
corepack pnpm --filter immich build
(cd server && corepack pnpm exec eslint src --max-warnings 0)
corepack pnpm --filter immich test -- --run \
  src/services/library.service.spec.ts \
  src/services/asset-media.service.spec.ts \
  src/controllers/index.spec.ts
corepack pnpm --filter immich-web check:svelte
corepack pnpm --filter immich-web check:typescript
corepack pnpm --filter immich-web build
corepack pnpm exec prettier --check i18n/
```

The unit test command runs the whole server project in this repo; on Node 22
three unrelated tests fail because they use the Node 24-only
`mkdtempDisposable*` helpers. Use Node 24 (the version pinned in `mise.toml`)
to avoid those failures.

## Conflict hotspots on future versions

| Area           | File / symbol                                                                                                |
| -------------- | ------------------------------------------------------------------------------------------------------------ |
| Mobile         | `MessagesImplBase.hashAsset`, `openOriginalStream`, new `openMediaFileStream`                                |
| Config         | `AdminConfigSchemaWithVisibility.library`, `defaults.library`                                                |
| Enum           | `ChecksumAlgorithm`, `ChecksumRehashTarget`, `JobName.LibraryRehash`                                         |
| Library import | `LibraryService.processEntity`, `handleSyncFiles`, `filterDuplicateChecksums`                                |
| Rehash         | `LibraryService.queueRecomputeChecksums`, `handleRehashChecksums`                                            |
| Upload dedupe  | `AssetMediaService.getUploadAssetIdByChecksum`, `bulkUploadCheck`, `uploadAsset`                             |
| Repository     | `AssetRepository.getLibraryContentChecksumMatch`, `getLibraryChecksums`, `streamChecksums`, `updateChecksum` |
| Web            | `LibrarySettings.svelte` checksum accordion                                                                  |
| CI             | `.github/workflows/docker.yml`, `.github/workflows/release.yml`                                              |

If upstream changes the config layout, keep the two config keys together so
the UI and server stay in sync:

```json
{
  "library": {
    "checksum": {
      "dedupeUploadsAgainstLibraries": true,
      "external": "sha1-path"
    }
  }
}
```
