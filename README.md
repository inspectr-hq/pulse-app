# Pulse

Pulse is a lightweight macOS menu bar uptime checker, built as a subproject of [Inspectr](https://inspectr.dev/).

It gives you a fast, always-available way to monitor APIs, MCP servers, websites, and health endpoints from your Mac menu bar.

## Why Monitoring Matters

Small outages, DNS/TLS issues, or degraded response times are easy to miss until users report them.

Pulse helps you:
- catch regressions quickly after deploys
- verify service health during local development
- see response-time trends at a glance
- keep lightweight incident context in a local history log

## What Pulse Does Today

- Native macOS menu bar app (`SwiftUI`, `MenuBarExtra`, macOS 13+)
- Multi-site monitoring with per-site method/threshold/keyword
- Automatic checks (default every `900` seconds)
- Manual checks from menu and site manager
- Per-site pause/unpause
- History log persisted to Application Support JSON (atomic writes, ISO-8601 dates)
- Optional webhook transitions (`up -> down`, `down -> up` when enabled), with multiple webhook rules and per-site filters

## Settings Reference

This section documents each setting and whether it currently has active runtime behavior.

### General

- `Start at login`
  - Status: Implemented
  - Behavior: Calls `SMAppService.mainApp.register()` / `unregister()` when settings are saved.

- `Show alert badge`
  - Status: Implemented
  - Behavior: Shows a Dock badge count for enabled monitors that are down, or up but slower than `Default Threshold`.

- `Ping Interval (seconds)`
  - Status: Implemented
  - Behavior: Reschedules periodic automatic checks using `MonitorScheduler`.

- `Auto Checks`
  - Status: Implemented
  - Behavior: `Pause when offline` skips automatic scheduler checks while macOS reports no active internet path. Manual checks always run.

- `Delay Checks (seconds between sites)`
  - Status: Implemented
  - Behavior: Adds delay between each monitor check in batch runs (`checkAll`) to reduce burst traffic and rate-limit pressure.

- `Failures to Alert (consecutive)`
  - Status: Implemented
  - Behavior: Alerting is gated until the same monitor fails N consecutive checks. Recovery can alert once the monitor returns up.

- `Default Threshold (ms)`
  - Status: Implemented
  - Behavior: Used as the initial threshold value for newly added monitors.

- `Default Method`
  - Status: Implemented
  - Behavior: Used as the initial HTTP method for newly added monitors.

### Menu Bar

- `Menu Items: Max N`
  - Status: Implemented
  - Behavior: Limits number of monitor rows rendered in dropdown (`prefix(maxItems)`).

- `Menu Icon: Show status color`
  - Status: Implemented
  - Behavior: If disabled, menu bar icon is rendered monochrome.

- `Colorize Icon` (`Always`, `Only failing`, `Never`)
  - Status: Implemented
  - Behavior:
    - `Always`: icon reflects current overall status color.
    - `Only failing`: icon is colored only for `down` state.
    - `Never`: icon is monochrome.

- `Show method`
  - Status: Implemented
  - Behavior: Shows/hides HTTP method in each dropdown row.

- `Show response time`
  - Status: Implemented
  - Behavior: Shows/hides response-time line in dropdown rows.

- `Show last checked`
  - Status: Implemented
  - Behavior: Shows/hides last checked time line in dropdown rows.

- `Show status code`
  - Status: Implemented
  - Behavior: Shows/hides HTTP status code in dropdown rows.

- `Status Colors` (`Up`, `Slow`, `Failure`, `Offline`)
  - Status: Implemented
  - Behavior: Applied to status dots in menu/site manager/history and to menu bar icon coloring when icon color mode allows it.

### Webhooks

- `Enable Webhooks`
  - Status: Implemented
  - Behavior: Enables webhook engine for alerting/recovery transitions (also gated by `Failures to Alert`).

- `Webhook Rules (multiple)`
  - Status: Implemented
  - Behavior: Configure multiple webhook endpoints, each with its own method/payload/retry policy.

- `Site Filter`
  - Status: Implemented
  - Behavior: Each webhook rule can target `All sites` or only selected monitors.

- `Send On` (`Alerting`, `Alerting and Recovery`)
  - Status: Implemented
  - Behavior:
    - `Alerting`: sends on `up -> down`
    - `Alerting and Recovery`: also sends on `down -> up`

- `Webhook URL`
  - Status: Implemented
  - Behavior: Required destination URL; empty/invalid URL disables send.

- `Method` (`POST`, `GET`)
  - Status: Implemented
  - Behavior: Sets webhook request method.

- `Payload`
  - Status: Implemented
  - Behavior: Template placeholders are replaced before send.

- `Retries`
  - Status: Implemented
  - Behavior: Retries failed webhook requests with exponential backoff.

- `Initial Backoff`
  - Status: Implemented
  - Behavior: Base delay in seconds used for retry backoff.

- Supported payload placeholders:
  - `$MESSAGE`, `$MONITOR`, `$STATUS`, `$URL`, `$TRIGGER`, `$STATUS_CODE`, `$RESPONSE_MS`, `$TIMESTAMP`

### History

- `History retention` (`1h`, `1d`, `1w`, `1m`, `Unlimited`)
  - Status: Implemented
  - Behavior: Applies rolling time-window pruning when new history events are appended.
  - Default: `1m`

## Runtime Rules (Current)

- `HEAD` checks fall back to `GET` when `405` or `501` is returned.
- Up status code range: `200...399`.
- Down status code range: `400...599` (and network/TLS/DNS/timeouts).
- Automatic scheduler checks only enabled monitors.
- Automatic scheduler checks can be paused when offline if `Auto Checks` is set to `Pause when offline`.
- Paused monitors are skipped by automatic checks.
- Manual checks can check paused monitors; UI status remains `Paused`, but real result is stored in history as a `manual` event.
- Batch checks can be delayed between sites using `Delay Checks`.
- Alert transitions are threshold-gated by `Failures to Alert`.
- Overall status logic:
  - `down` if any enabled monitor is down
  - `checking` if any enabled monitor is checking and none are down
  - `up` if at least one enabled monitor is up and none are down/checking
  - `unknown` if enabled monitors exist and none has a completed check yet
  - `neutral` if no enabled monitors

## Persistence

- Monitors + app settings: `UserDefaults` JSON
- History events: `~/Library/Application Support/Pulse/history.json`
  - ISO-8601 date encoding
  - Atomic writes
  - Corruption fallback to empty history

## Build & Test

From project root:

```bash
cd /Users/tim.haselaars/Sites/apps/pulse/app
swift build
swift test
```

## Relationship to Inspectr

Pulse is a focused local utility in the Inspectr ecosystem. It complements broader tooling from [inspectr.dev](https://inspectr.dev/) with quick desktop monitoring during development and operations.
