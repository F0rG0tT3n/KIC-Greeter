# KIC Greeter Changelog

## 1.1.0

### Added

- Added a fourth **Overtime Mythic+** tab with its own independently configurable message list.
- Added automatic messages for completed Mythic+ keystones that finish after the timer expires.
- Added 10 default overtime completion messages, with the first 2 enabled on a clean installation.
- Added the same **Add**, **Edit**, **Remove**, and **Use** controls available in the other message tabs.

### Behavior

- Timed and overtime completions now use separate message lists.
- A timed keystone only selects a message from **Timed Mythic+**.
- A completed but depleted keystone only selects a message from **Overtime Mythic+**.
- Practice runs remain silent.
- Existing saved greetings and settings remain unchanged; the new overtime list is initialized automatically.

## 1.0.1

### Changed

- Made the currently selected tab much easier to identify.
- The active tab now remains visibly pressed, uses gold text, and displays a gold selection line instead of appearing disabled and greyed out.

## 1.0.0

### Initial Release

- Automatic random greetings when joining another player's group.
- Configurable maximum group size for join greetings.
- Separate message lists for timed Mythic+ completions and successful Vote to Abandon outcomes.
- Numbered message editor with enable, edit, remove, and add controls.
- Draggable minimap button and `/kicgreet` configuration command.
- Saved messages, enabled states, group-size limit, and window positions.
