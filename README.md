# KIC LFG Greeter

A World of Warcraft Retail addon that sends configurable random messages when
you join a party, time a Mythic+ keystone, or successfully Vote to Abandon one.

## Behavior

- Sends exactly one randomly selected greeting when you join an existing group
  whose member count is at or below your configured maximum.
- Does not greet when your invitation causes a group to be formed and makes
  you the party leader.
- Uses instance chat for matchmade instance groups, raid chat for raids, and
  party chat otherwise.
- Does not greet when reloading the UI while already grouped.
- Does not send during WoW's chat messaging lockdown.
- Sends one random enabled timed-completion message after a Mythic+ dungeon is
  completed within its time limit. Depleted keys and practice runs stay silent.
- Briefly retries Mythic+ outcome messages if chat is still locked when the
  relevant event fires.
- Sends one random enabled abandon message only when a Mythic+ Vote to Abandon
  succeeds. Failed votes stay silent.
- Provides a draggable minimap button that opens the message editor.
- Saves enabled states, custom messages, removals, and window positions.

## Message editor

Click the gold **G** button on the minimap or type `/kicgreet` to open the
editor. Use the **Join Greetings**, **Timed Mythic+**, and **Abandoned Mythic+**
tabs to maintain each message list independently. Every row has a number,
message text, **Edit** and **Remove** buttons, and a **Use** checkbox. Add a
custom message with the text field at the bottom. If every message in a tab is
disabled or removed, that feature stays silent.

On the **Join Greetings** tab, the **Maximum group size** field counts every
group member, including you. Its clean-install default is `4`, which allows
greetings in groups with up to four members and suppresses them in groups of
five or more.
Values are limited to the range 1–40. This limit does not apply to timed
Mythic+ completion messages.

## Install

Copy both the `KIC` and `KIC-LFGGreeter` folders into:

```text
World of Warcraft\_retail_\Interface\AddOns\
```

Restart the game or run `/reload`, then enable **KIC LFG Greeter** in the
AddOns list. WoW displays the Greeter beneath a **KIC** parent entry. The two
folders must remain siblings directly inside `Interface\AddOns`; do not place
`KIC-LFGGreeter` physically inside the `KIC` folder. The parent is an optional
dependency: without it the Greeter still loads, but it cannot appear in the KIC
group.

## Testing

Join another player's party while the addon is enabled. About one second after
joining, the addon sends one of the enabled join greetings to the group's chat
channel. A clean installation includes ten join greetings with the first five
enabled. The timed-completion and successful-abandon lists also contain ten
messages, with their first two and first three entries enabled respectively.
