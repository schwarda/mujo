# Mujo notification settings

Approved scope: the conversation through “ok sprav” on 2026-10-31, with the user's subsequent native iOS Settings correction below taking precedence.

## Native settings correction

- Use native inset-grouped List/Section headers and footers, system typography and navigation. Retain Mujo's Sakura background and accent.
- Custom rows open editing on tap. Swipe left reveals a destructive Remove action; no pencil or always-visible removal button.
- The custom editor uses a native Form and navigation toolbar Cancel/Save actions.
- Open Settings is a standard tappable list row, not a prominent glass button.
- Until notification permission is granted, hide every alert and badge preference. If denied, show only Open Settings and a short explanatory footer. If undetermined, Enable Notifications can ask iOS directly.
- Preserve saved choices when permission is denied, refresh on foreground, and dismiss an open editor if permission is revoked.
- No simulator testing; the user will test visual appearance and device behavior.

- Notifications is the first Home menu item. It opens an in-app screen matching App Info: SakuraBackground, MujoTheme fonts/tint, glass groups, matching back button, scrollable content and Dynamic Type.
- Alerts section: recommended defaults (50%, 75%, final 15/30 minutes, five minutes) as one toggle; limit reached as a separate toggle; any number of distinct custom percentages from 1–99, with add/edit/remove. Percentages mean daily limit used. Recommended and custom may coexist; coincident alerts produce one notification.
- Badges section: remaining minutes on the app icon, independently enabled. Turning off clears the current badge and every producer honors the preference.
- Existing installations retain enabled recommended alerts, expiry and badge, with no custom alerts.
- System notification permission is distinct from Mujo preferences. Request only after a user action when undetermined; denied links to iOS notification settings. Refresh on foreground and returning to Home. Settings remain editable without permission.
- Home gains a notice in the existing stack when system permission is denied. It explains the consequence and directs to Menu → Notifications. It disappears after permission changes.
- English copy follows current Mujo usage: short, concrete and neutral, no guilt or persuasion; check with copy-editing.
- Shared App Group preferences drive the app and ActivityMonitor. Preserve measurements, widgets, daily limits and unrelated work. No dependencies, commits or publishing.

Approach: extend the existing milestone policy and delivery boundary, rather than create a second measurement activity. Preserve the first-day monitoring session. Its existing checkpoints can deliver custom thresholds when crossed; show that first-day alerts may arrive at the next usage update. On subsequent days register custom minute thresholds with existing monitoring. Round custom percentages up to whole minutes; 100% is owned by Limit reached.

Verification: policy/persistence/threshold/badge tests, simulator UI flow and appearance, unsigned app/extensions build. Real usage callbacks and system banner delivery need an authorized physical device.
