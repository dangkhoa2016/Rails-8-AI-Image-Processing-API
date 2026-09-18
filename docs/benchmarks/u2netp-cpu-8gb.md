# U²-NetP CPU / 8 GB qualification

## Status

```text
U2NETP_8GB_QUALIFICATION=NOT_RUN
```

This document defines the authority gate; it does not claim a benchmark result.

An authoritative run must execute inside an independently verified memory limit of **8 GiB or less**. Merely running on a host that has more RAM is not evidence of the 8 GB product target.

Required image geometries:

- 512 × 512
- 1024 × 1024
- 1920 × 1080
- 4000 × 3000

Run with the checksum-qualified U²-NetP ONNX artifact installed under the documented local model authority:

```bash
IMAGE_AI_ENABLED=true \
IMAGE_AI_MAX_CONCURRENCY=1 \
U2NETP_BENCHMARK_CASES=/path/to/benchmark-cases.json \
bundle exec ruby script/benchmark_u2netp_cpu_8gb.rb
```

The harness fails closed if it cannot read a cgroup memory limit or if that limit exceeds 8 GiB.

A successful authoritative run must emit all of:

```text
NO_OOM_ON_8GB=PASS
AI_CONCURRENCY_BOUND=PASS
SESSION_REUSE=PASS
NO_PER_REQUEST_MODEL_LOAD=PASS
```

The JSON report also records per-case latency and process peak RSS. These results become release evidence only after an observed run; the presence of this harness alone is not qualification evidence.
