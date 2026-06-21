# Branch Strategy — infra-repo

## Strategy
GitHub Flow + Release Tagging

## Branches

| Branch | Description |
|---|---|
| `main` | Protected. Source of truth for all infrastructure code. |
| `feat/<issue-id>-<subject>` | New infrastructure resource |
| `fix/<issue-id>-<subject>` | Fix to existing Terraform/Helm definition |
| `chore/<issue-id>-<subject>` | Module version bumps, cleanup |

## Flow

```
main → <type>/<issue-id>-<subject> → PR → merge to main → tag vX.Y.Z
```

A release tag is created after every successful `terraform apply` on `main`.

## Branch Protection (`main`)

- No direct push allowed
- PR required before merging
- All CI status checks must pass
- Minimum 1 approval required