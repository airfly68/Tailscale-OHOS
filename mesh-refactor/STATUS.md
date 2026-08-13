# M18 Taildrop media cache and save reliability (2026-08-03)

- Status: **completed for local acceptance; real-device gallery/offline interaction remains unverified**.
- Image prefetch now retains the staged original when thumbnail decoding fails, so an offline inbox can still show the source image and keep the media save action available.
- Persisted media cache recovery now promotes legacy cached image/video files into the media-preview model; video thumbnails remain best-effort.
- Media export now supports existing provider URIs, restores a 60-second save timeout, and falls back from short-term asset creation to the system creation dialog when a device/provider rejects the first path.
- No Taildrop request/response fields, route parameters, persisted user-data schema, or remote-delete ordering changed.

| Command/evidence | Exit code | Result |
| --- | ---: | --- |
| `git diff --check` | 0 | No whitespace errors; only existing LF/CRLF conversion warnings. |
| `powershell -ExecutionPolicy Bypass -File scripts/build.ps1` | 0 | Go AArch64 library, ArkTS compilation, signed HAP packaging, and artifact verification passed. |
| Full visual/device interaction review | not executed | Per repository policy for routine test iterations; the user should verify offline preview and online gallery save on the target device. |

No production Release build or upload was performed.
