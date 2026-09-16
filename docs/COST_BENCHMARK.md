# Cost Benchmark Protocol

## Observation Window

- Keep the dev platform configuration stable for at least 72 hours.
- Take one snapshot daily at approximately the same time.
- Do not combine data from periods separated by Terraform apply/destroy operations.
- Report retail-equivalent cost, consumed credits, and net payable separately.

## Daily Snapshot

Run:

```bash
scripts/cost-benchmark.sh snapshot
```

The script makes one Cost Explorer API request and stores sanitized AWS,
Kubernetes, and Prometheus data under `../benchmark-results/cost/`. It reads the
remaining account credit through the Free Tier API. Use
`--credit-balance 198.42` only as a fallback if that API is unavailable.

Generate the current summary without querying AWS again:

```bash
scripts/cost-benchmark.sh summary
```

## Daily Agent Prompt

```text
Chạy cost benchmark snapshot ngày hôm nay trong nexus-infra.
Kiểm tra đúng account 863547508328, chạy script snapshot đúng một lần,
so sánh với snapshot trước và báo credit burn, thay đổi tài nguyên và bất thường.
Không thay đổi hạ tầng hoặc gọi Cost Explorer thêm lần thứ hai.
```

If the Free Tier API is unavailable, provide the current balance with
`--credit-balance` and explicitly record that fallback.
