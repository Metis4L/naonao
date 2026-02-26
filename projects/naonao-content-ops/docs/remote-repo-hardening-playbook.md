# Remote Repo Hardening Playbook

Last updated: 2026-02-26
Scope: GitHub-hosted remote repository hardening for `naonao-content-ops` pipeline.

## A. Branch protection baseline (manual on remote)

1. Protect default branch (`main`):
   - Require pull request before merge
   - Require at least 1 approved review
   - Dismiss stale approvals on new commits
   - Require conversation resolution
   - Restrict force push and branch deletion
2. Restrict direct push to admins/release bot only (if needed).

### Verification command (GitHub CLI)

```bash
gh api repos/<owner>/<repo>/branches/main/protection
```

## B. Required checks

Set required checks to include at least:

- `work-order-schema-validation`
- `hard-validator-gate`
- `executor-capability-regression`

Optional recommended:

- secret scanning status check
- dependency review

### Verification

```bash
gh api repos/<owner>/<repo>/branches/main/protection/required_status_checks
```

## C. Secret scanning and push protection

1. Enable secret scanning
2. Enable push protection
3. Enable Dependabot alerts + secret scanning alerts ingestion

### Verification

```bash
gh api repos/<owner>/<repo> | jq '.security_and_analysis'
```

## D. Credential rotation SOP

When leakage is suspected:

1. Freeze merge to protected branch
2. Revoke leaked token/key from source provider
3. Reissue least-privilege credential
4. Update CI secrets (`Actions Secrets`) and local `.env` references
5. Re-run smoke checks and audit logs

### Verification

```bash
# list action secrets metadata
gh secret list --repo <owner>/<repo>
```

## E. Historical leak incident response

1. Identify exposed secret scope and blast radius
2. Revoke/rotate first (before history rewrite)
3. Rewrite git history (if necessary) using `git filter-repo`/BFG
4. Force-push rewritten history to remote (requires change window)
5. Invalidate caches, forks, and artifacts where possible
6. Publish incident note with timeline and compensating controls

## F. Local checks executable now

```bash
# 1) scan tracked files for likely secrets (lightweight heuristic)
git grep -nE '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----)' -- .

# 2) confirm no accidental env files tracked
git ls-files | grep -E '(^|/)\.env(\.|$)' || true

# 3) list high-risk workflow permissions (manual review)
grep -R "permissions:" -n .github/workflows || true
```

## G. User manual checklist (remote-only items)

These cannot be fully enforced locally and require repository admin actions:

- [ ] Enable and verify branch protection on `main`
- [ ] Configure required checks list
- [ ] Enable secret scanning + push protection
- [ ] Audit and tighten GitHub App / PAT scopes
- [ ] Rotate all automation credentials older than 90 days
- [ ] Validate protection settings via `gh api` commands above
