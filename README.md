# KIC LFG Greeter

A World of Warcraft Retail addon that greets a newly joined party with a
randomly selected, configurable message.

## Behavior

- Sends exactly one randomly selected greeting when you join an existing
  five-player group.
- Does not greet when your invitation causes a group to be formed and makes
  you the party leader.
- Uses instance chat for matchmade instance groups and party chat otherwise.
- Does not greet when reloading the UI while already grouped.
- Does not send during WoW's chat messaging lockdown.
- Does not greet raids.
- Provides a draggable minimap button that opens the greeting editor.
- Saves enabled states, custom greetings, removals, and window positions.
- Applies an inclusive, configurable maximum group size before greeting.

## Greeting editor

Click the gold **G** button on the minimap or type `/kicgreet` to open the
editor. Each row has a number, greeting text, **Edit** and **Remove** buttons,
and a **Use** checkbox. Add a custom greeting with the text field at the
bottom. If every greeting is disabled or removed, the addon stays silent.

The **Maximum group size** field at the top counts every group member,
including you. For example, a value of `5` allows greetings in groups with up
to five members and suppresses them in groups of six or more. Values are
limited to the range 1–40.

## Install

Copy the `KIC-LFGGreeter` folder into:

```text
World of Warcraft\_retail_\Interface\AddOns\
```

Restart the game or run `/reload`, then enable **KIC LFG Greeter** in the
AddOns list.

## Testing

Join another player's party while the addon is enabled. About one second after
joining, the addon sends one of the enabled greetings to the group's chat
channel.
