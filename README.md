# nexus-infra

## Cloudflare credentials

ACM DNS validation uses the Cloudflare Terraform provider. Export a scoped API token before planning or applying the dev environment:

```bash
export CLOUDFLARE_API_TOKEN="..."
```

Required token permissions:

- Zone: Zone: Read
- Zone: DNS: Edit
