---
name: review-pr
description: Review a GitHub pull request for code quality, correctness, and style. Use when asked to review a PR or when a PR number is mentioned.
argument-hint: [pr-number]
disable-model-invocation: true
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob, Bash(gh pr *), Bash(gh api *)
---

# PR Review

Review pull request #$ARGUMENTS.

## Context

- PR diff: !`gh pr diff $ARGUMENTS`
- PR description: !`gh pr view $ARGUMENTS`
- Changed files: !`gh pr diff $ARGUMENTS --name-only`

## Review checklist

For each changed file, evaluate:

1. **Correctness** — Does the logic do what the PR description says? Are there edge cases?
2. **Readability** — Are names clear? Is the code easy to follow?
3. **Testing** — Are there tests for new behavior? Do existing tests still pass?
4. **Security** — Any hardcoded secrets, SQL injection risks, or unsafe inputs?
5. **Performance** — Any obvious N+1 queries, unnecessary allocations, or blocking calls?

## Output format

Structure your review as:

### Summary
One paragraph overview of what the PR does and your overall assessment.

### File-by-file review
For each file with findings:
- **File path** and line numbers
- What the issue is
- Suggested fix (with code if helpful)

### Verdict
One of: **Approve**, **Request changes**, or **Needs discussion** — with a brief justification.
