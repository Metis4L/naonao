# Security & Compliance Closure Checklist

## Sensitive files
- [x] Add `.gitignore` for `auth.json`, `auth-profiles.json`, `.env*`
- [x] Add pre-commit guard to block sensitive files
- [ ] Rotate any credentials that may have appeared in local temp files (manual)

## Repo protections
- [x] Keep `archive/` strategy for noisy artifacts
- [x] Keep baseline promotion approval packet trail
- [x] Keep work-order schema hard-fail before execute

## Cross-agent boundary
- [x] C-class changes require explicit user approval
- [x] Baseline overwrite disabled by default path
- [x] Execution reports include environment fingerprints

## Remaining manual actions
1. Confirm no sensitive files were pushed to remote history.
2. Enable branch protection / required checks on remote repo (if not enabled).
3. Review Telegram notification content to avoid leaking local absolute paths if needed.
