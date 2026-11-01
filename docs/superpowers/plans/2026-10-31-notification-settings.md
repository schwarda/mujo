# Notification Settings Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task by task. Preserve existing uncommitted changes.

**Goal:** Add Home notification guidance and configurable alerts and badges.

**Architecture:** One persisted App Group policy consumed by the UI, milestone planner, monitor extension and badge producers. Extend existing monitoring without resetting first-day measurement.

**Tech Stack:** Swift 6, SwiftUI, UserNotifications, DeviceActivity; iOS 26.0.

**Spec:** `docs/superpowers/specs/2026-10-31-notification-settings-design.md`

## Global Constraints
- Follow MujoTheme, SakuraBackground, existing navigation and glass styling.
- No dependencies, commits, publishing or unrelated changes.
- Defaults preserve existing delivery. No automatic permission prompts.

## Review Focus
- Denied permissions and foreground changes: settings and Home refresh.
- Percentage collisions, short limits and rounding: one notification per checkpoint.
- First-day edits and late callbacks: measurement remains intact and no backlog spam.
- Badge disabled: all producers clear/keep zero, reenabling restores current count.
- Shared persisted preferences: reload, invalid values and existing installations.

### Task 1: Shared policy and meaningful tests
- [x] Write NotificationPreferencesTests for persistence/defaults, filtering, custom rounding, coincident thresholds, late checkpoints and no backlog; watch missing feature fail.
- [x] Add Shared/NotificationPreferences.swift; extend NotificationMilestone and AppConfiguration.Monitoring for custom thresholds.
- [x] Add disabled-badge test; make RemainingTimeBadge and ScreenTimeManager respect the policy.
- [x] Register the shared policy in app/monitor targets and pass focused tests.

### Task 2: Delivery integration
- [x] Consume fresh preferences at delivery; retain daily deduplication and legacy sent keys, coalesce coincident alerts, send at most the latest crossed alert.
- [x] Extend monitoring registration and callback validation for custom thresholds. Preserve the active first-day session and its crossing fallback.
- [x] Expose ScreenTimeManager refresh for changed preferences without resetting measurement.

### Task 3: Settings and Home
- [x] Add NotificationSettingsScreen.swift with system permission status, alert group, expiry toggle, repeatable percentage editor and badge group.
- [x] Add first Home menu item/navigation and denied-permission notice; refresh settings on appearance and foreground.
- [x] Add UI test for navigation, custom add/edit/delete and independent toggles.
- [x] Check copy; run focused tests and unsigned build, review the diff.
- [ ] User visual/device acceptance (user explicitly took over testing; no further simulator work).

## Progress
- Native iOS Settings correction implemented after user review: inset-grouped list, section footers, tap-to-edit and swipe-to-remove, native editor/navigation, standard Settings row, and permission-gated preferences. UI tests adapted; simulator execution intentionally omitted at the user's request.
- Investigation complete. Existing dirty work preserved; implementation branch codex/notification-settings.
- Decision: work in the current checkout to retain the user's uncommitted Home/onboarding changes.
- Decision: first-day custom alerts use the next existing checkpoint; later sessions register custom minute thresholds. Explain the first-day timing in settings, rather than reset measurement.
- Tasks 1–3 implemented. Focused policy/badge/milestone/monitoring tests and settings UI flow passed. iPhone unsigned app/extensions build passed.
- Full unit suite: 142 tests, six failed assertions in four unchanged onboarding tests: countdownDurationUsesSelectedLimit (3), countdownStartsImmediatelyBeforeSlowerHandoff, sakuraGustCoversScreenAtHomeReveal, exposesEqualBottomEdges. No unrelated fixes.
- Independent read-only review completed. Review raised custom 99% rounding to expiry on short limits. Decision: retain independent user-selected custom alerts, even if rounded to the final minute; the expiry toggle controls the built-in expiry alert, not explicit custom reminders. Excluding the threshold would silently drop the user's chosen custom alert. UI now discloses whole-minute rounding and next-usage-update delivery for all custom alerts (also honest when app remains closed after the first day).
- No commit, push or deployment. Existing and concurrent onboarding work preserved.
