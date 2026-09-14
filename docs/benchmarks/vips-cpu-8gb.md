# Vips CPU / 8 GiB qualification

## Result

**PASS, for the deterministic image-processing workloads measured here.** The
complete suite ran in the project Docker runtime with a hard 8 GiB memory and
swap limit. All 50 direct workload profiles completed their one warm-up and
five measured runs, the authenticated HTTP path returned `200` for every
corpus class, and all acceptance gates passed. This is observed benchmark
evidence, not a latency SLO or a guarantee for later AI workloads.

The runner writes an ignored raw JSON file at
`tmp/phase12-benchmark-full/vips-cpu-8gb-result.json`. The instance used for
this report was rendered from that file on 2026-09-14 and then removed with
the rest of the temporary benchmark artifacts.

## Runtime and command

| Item | Observed value |
| --- | --- |
| Host OS / kernel | Ubuntu 24.04.5 LTS / Linux 6.8.0-110-generic |
| Host CPU / cores | Intel(R) Xeon(R) CPU @ 2.60GHz / 4 |
| Host RAM | 15,713,267,712 B (14.64 GiB) |
| Docker client / server | 28.0.1 / 28.0.1 |
| Docker image | `rails-8-ai-image-processing-api:phase3-vips` |
| Docker cgroup memory / swap limit | 8,589,934,592 B / 8,589,934,592 B (8 GiB each) |
| Docker OS / kernel | Debian GNU/Linux 13 (trixie) / 6.8.0-110-generic |
| Ruby | ruby 3.3.12 |
| libvips runtime package / API | `libvips42t64 8.16.1-1+deb13u1` / 8.16.1 |
| Available memory at runner start | 7,494,221,824 B (6.98 GiB; cgroup-aware) |
| Result timestamp | 2026-09-14T07:24:13Z |

The Docker runner was started with `--memory=8g --memory-swap=8g`, then ran:

```sh
RAILS_ENV=test ruby script/benchmark_vips_cpu_8gb.rb \
  --output tmp/phase12-benchmark-full --workers 3
```

## Corpus

| Fixture | Format | Input bytes | Dimensions | Alpha |
| --- | --- | ---: | --- | --- |
| full_hd_jpeg | JPEG | 33,441 | 1920×1080 | no |
| large_jpeg | JPEG | 188,801 | 4000×3000 | no |
| square_png | PNG | 60,501 | 4096×4096 | no |
| transparent_png | PNG | 11,552 | 1920×1080 | yes |
| webp | WebP | 4,010 | 1920×1080 | no |

## Direct pipeline workloads

Every row is a separate direct `ImageLab::Pipeline` profile with one warm-up
and five measured samples. Wall values are median `(min–max)` milliseconds;
RSS is median average/peak MiB. CPU can exceed 100% because libvips uses more
than one CPU core.

| Fixture | Input | Workload | Output | Wall ms | CPU ms | RSS avg/peak MiB | CPU % |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| full_hd_jpeg | 33441 B, 1920×1080 | decode_encode | 9316 B, 1920×1080 | 33.65 (33.19–59.42) | 33.73 | 145.21/145.21 | 97.87 |
| full_hd_jpeg | 33441 B, 1920×1080 | resize | 4877 B, 1280×720 | 27.10 (23.57–28.36) | 36.44 | 154.37/154.37 | 135.83 |
| full_hd_jpeg | 33441 B, 1920×1080 | crop | 2219 B, 512×512 | 9.14 (7.73–18.97) | 9.18 | 157.70/157.70 | 99.72 |
| full_hd_jpeg | 33441 B, 1920×1080 | rotate | 11178 B, 1080×1920 | 38.96 (38.30–57.68) | 42.80 | 157.70/157.70 | 103.96 |
| full_hd_jpeg | 33441 B, 1920×1080 | grayscale | 4290 B, 1920×1080 | 27.01 (22.72–27.94) | 38.99 | 157.64/157.64 | 144.58 |
| full_hd_jpeg | 33441 B, 1920×1080 | blur | 9316 B, 1920×1080 | 42.89 (38.00–55.53) | 49.07 | 157.63/157.63 | 114.41 |
| full_hd_jpeg | 33441 B, 1920×1080 | sharpen | 9316 B, 1920×1080 | 111.27 (102.39–134.06) | 252.96 | 171.31/172.14 | 227.34 |
| full_hd_jpeg | 33441 B, 1920×1080 | tint | 8598 B, 1920×1080 | 46.77 (41.09–57.67) | 62.07 | 175.93/175.93 | 134.36 |
| full_hd_jpeg | 33441 B, 1920×1080 | mixed_5 | 5550 B, 720×1280 | 132.19 (121.85–172.29) | 292.36 | 239.77/240.38 | 216.12 |
| full_hd_jpeg | 33441 B, 1920×1080 | mixed_10 | 2031 B, 360×640 | 74.94 (65.11–105.73) | 130.50 | 293.84/293.84 | 174.70 |
| large_jpeg | 188801 B, 4000×3000 | decode_encode | 43087 B, 4000×3000 | 186.18 (159.57–226.62) | 173.56 | 329.42/329.42 | 97.98 |
| large_jpeg | 188801 B, 4000×3000 | resize | 4248 B, 960×720 | 120.21 (116.35–181.83) | 243.23 | 329.42/329.42 | 202.58 |
| large_jpeg | 188801 B, 4000×3000 | crop | 2219 B, 512×512 | 9.62 (8.52–10.16) | 9.26 | 329.42/329.42 | 100.46 |
| large_jpeg | 188801 B, 4000×3000 | rotate | 46820 B, 3000×4000 | 172.84 (160.72–189.43) | 217.38 | 329.45/329.45 | 126.86 |
| large_jpeg | 188801 B, 4000×3000 | grayscale | 18285 B, 4000×3000 | 118.63 (103.58–128.87) | 194.32 | 329.46/329.46 | 164.46 |
| large_jpeg | 188801 B, 4000×3000 | blur | 43087 B, 4000×3000 | 180.12 (175.34–227.86) | 244.81 | 313.69/313.69 | 136.97 |
| large_jpeg | 188801 B, 4000×3000 | sharpen | 43087 B, 4000×3000 | 596.52 (569.24–723.25) | 1507.13 | 315.22/315.22 | 237.69 |
| large_jpeg | 188801 B, 4000×3000 | tint | 42343 B, 4000×3000 | 219.39 (177.17–295.94) | 290.34 | 315.23/315.23 | 139.25 |
| large_jpeg | 188801 B, 4000×3000 | mixed_5 | 4190 B, 720×960 | 412.53 (349.77–436.33) | 762.84 | 316.54/316.54 | 183.64 |
| large_jpeg | 188801 B, 4000×3000 | mixed_10 | 2031 B, 360×640 | 188.52 (150.19–231.55) | 316.46 | 323.11/323.90 | 164.29 |
| square_png | 60501 B, 4096×4096 | decode_encode | 60309 B, 4096×4096 | 284.43 (220.60–334.51) | 247.86 | 376.44/376.44 | 98.03 |
| square_png | 60501 B, 4096×4096 | resize | 3707 B, 720×720 | 168.23 (147.59–206.30) | 309.10 | 384.24/384.24 | 180.97 |
| square_png | 60501 B, 4096×4096 | crop | 2219 B, 512×512 | 9.83 (8.14–13.11) | 9.04 | 391.12/391.12 | 93.90 |
| square_png | 60501 B, 4096×4096 | rotate | 60309 B, 4096×4096 | 249.69 (229.77–294.82) | 301.55 | 391.20/391.20 | 122.36 |
| square_png | 60501 B, 4096×4096 | grayscale | 25413 B, 4096×4096 | 167.95 (143.56–186.97) | 268.43 | 391.20/391.20 | 173.44 |
| square_png | 60501 B, 4096×4096 | blur | 60309 B, 4096×4096 | 245.81 (217.04–325.14) | 349.75 | 356.70/356.70 | 142.53 |
| square_png | 60501 B, 4096×4096 | sharpen | 60309 B, 4096×4096 | 940.72 (761.50–1032.60) | 2054.75 | 357.75/357.82 | 227.95 |
| square_png | 60501 B, 4096×4096 | tint | 58794 B, 4096×4096 | 266.01 (231.50–336.42) | 370.28 | 357.95/357.95 | 139.20 |
| square_png | 60501 B, 4096×4096 | mixed_5 | 3170 B, 720×720 | 405.48 (386.67–640.43) | 882.56 | 374.39/376.69 | 206.89 |
| square_png | 60501 B, 4096×4096 | mixed_10 | 2031 B, 360×640 | 238.11 (199.04–267.41) | 406.98 | 393.07/395.41 | 171.57 |
| transparent_png | 11552 B, 1920×1080 | decode_encode | 11360 B, 1920×1080 | 45.14 (40.50–56.84) | 44.18 | 404.38/404.38 | 99.32 |
| transparent_png | 11552 B, 1920×1080 | resize | 5779 B, 1280×720 | 66.09 (51.92–93.12) | 107.13 | 406.39/407.43 | 153.90 |
| transparent_png | 11552 B, 1920×1080 | crop | 2603 B, 512×512 | 10.45 (9.86–13.92) | 10.36 | 407.43/407.43 | 100.01 |
| transparent_png | 11552 B, 1920×1080 | rotate | 13594 B, 1080×1920 | 64.54 (49.60–80.93) | 61.80 | 407.43/407.43 | 104.25 |
| transparent_png | 11552 B, 1920×1080 | grayscale | 7275 B, 1920×1080 | 38.34 (36.09–49.88) | 52.48 | 407.43/407.43 | 139.51 |
| transparent_png | 11552 B, 1920×1080 | blur | 11360 B, 1920×1080 | 56.56 (48.61–73.14) | 64.69 | 342.29/342.29 | 111.54 |
| transparent_png | 11552 B, 1920×1080 | sharpen | 11360 B, 1920×1080 | 210.47 (186.63–240.29) | 498.98 | 358.04/358.27 | 237.77 |
| transparent_png | 11552 B, 1920×1080 | tint | 11362 B, 1920×1080 | 73.26 (61.66–80.37) | 95.33 | 358.27/358.27 | 130.11 |
| transparent_png | 11552 B, 1920×1080 | mixed_5 | 7487 B, 720×1280 | 234.52 (210.46–359.99) | 532.14 | 438.23/441.61 | 234.28 |
| transparent_png | 11552 B, 1920×1080 | mixed_10 | 2749 B, 360×640 | 109.52 (101.32–168.57) | 191.31 | 442.79/454.06 | 165.62 |
| webp | 4010 B, 1920×1080 | decode_encode | 8974 B, 1920×1080 | 35.23 (31.08–36.28) | 33.10 | 442.48/442.48 | 101.04 |
| webp | 4010 B, 1920×1080 | resize | 4844 B, 1280×720 | 29.98 (25.80–34.78) | 34.26 | 427.07/427.07 | 113.91 |
| webp | 4010 B, 1920×1080 | crop | 2253 B, 512×512 | 8.64 (7.09–9.61) | 8.39 | 427.07/427.07 | 100.45 |
| webp | 4010 B, 1920×1080 | rotate | 10715 B, 1080×1920 | 44.54 (37.80–46.41) | 42.86 | 427.07/427.07 | 101.90 |
| webp | 4010 B, 1920×1080 | grayscale | 4331 B, 1920×1080 | 33.45 (26.54–36.72) | 48.39 | 427.07/427.07 | 154.16 |
| webp | 4010 B, 1920×1080 | blur | 9356 B, 1920×1080 | 52.90 (35.33–73.24) | 61.57 | 410.02/410.02 | 116.40 |
| webp | 4010 B, 1920×1080 | sharpen | 9026 B, 1920×1080 | 124.09 (95.35–189.50) | 258.98 | 386.95/386.95 | 208.70 |
| webp | 4010 B, 1920×1080 | tint | 8954 B, 1920×1080 | 41.24 (35.17–46.42) | 54.40 | 367.46/367.46 | 132.02 |
| webp | 4010 B, 1920×1080 | mixed_5 | 6139 B, 720×1280 | 163.17 (148.33–207.99) | 292.92 | 372.66/372.66 | 188.91 |
| webp | 4010 B, 1920×1080 | mixed_10 | 2606 B, 360×640 | 120.60 (97.86–144.00) | 175.07 | 387.52/389.90 | 149.23 |

## Authenticated HTTP lifecycle

One real JSON sign-in plus multipart `POST /images/process` ran for each
fixture. The values below include the Rails/Rack/Devise/JWT/controller path;
the scratch-directory audit passed for every request.

| Fixture | Status | Output | Wall ms | CPU ms | RSS avg/peak MiB | CPU % | Tempfile cleanup |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| full_hd_jpeg | 200 | 9,316 B, 1920×1080 | 443.90 | 390.20 | 403.39/410.06 | 87.90 | PASS |
| large_jpeg | 200 | 43,087 B, 4000×3000 | 423.60 | 371.82 | 437.19/446.46 | 87.78 | PASS |
| square_png | 200 | 60,309 B, 4096×4096 | 461.08 | 427.72 | 481.55/494.62 | 92.76 | PASS |
| transparent_png | 200 | 11,360 B, 1920×1080 | 141.65 | 111.92 | 487.92/494.45 | 79.01 | PASS |
| webp | 200 | 8,974 B, 1920×1080 | 126.25 | 107.15 | 456.68/474.80 | 84.86 | PASS |

## Concurrency and gates

The representative `mixed_5` workload used separate Ruby worker processes.
The runner checks cgroup-aware available memory before every level and would
terminate an active level above 6 GiB aggregate worker RSS.

| Workers | Aggregate RSS peak | Status |
| ---: | ---: | --- |
| 1 | 222.50 MiB | PASS |
| 2 | 440.33 MiB | PASS |
| 3 | 664.10 MiB | PASS |

| Gate | Result | Evidence |
| --- | --- | --- |
| `NO_OOM` | PASS | 50 direct profiles and all 1/2/3-worker levels exited successfully. |
| `NO_UNBOUNDED_RSS_GROWTH` | PASS | Every direct profile's fifth measured RSS peak was within 15% + 16 MiB of its first. |
| `TEMPFILE_CLEANUP` | PASS | All five authenticated HTTP scenarios restored `tmp/image_lab` to its prior entries. |
| `OUTPUT_LIMITS_ENFORCED` | PASS | A real oversized resize raised `ImageLab::Errors::OutputLimitExceeded`. |
| `SAMPLES_RECORDED` | PASS | Exactly five measured direct samples per profile, after one warm-up. |

## Interpretation and limits

This evidence qualifies the current deterministic Vips path under the stated
8 GiB cgroup limit. It deliberately does not qualify any AI model, background
removal, remote ingestion, job queue, sustained external traffic, or a
user-facing latency promise. Run this benchmark again after changing the
Docker image, libvips, image limits, workload definitions, CPU allocation, or
memory limit.
