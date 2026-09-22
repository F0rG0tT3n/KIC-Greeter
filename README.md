# KIC LFG Greeter

A minimal World of Warcraft Retail addon that greets a newly joined party with
`hi`.

## Behavior

- Sends exactly one greeting when you join an existing five-player group.
- Does not greet when your invitation causes a group to be formed.
- Uses instance chat for matchmade instance groups and party chat otherwise.
- Does not greet when reloading the UI while already grouped.
- Does not send during WoW's chat messaging lockdown.
- Does not greet raids.

## Install

Copy the `KIC-LFGGreeter` folder into:

```text
World of Warcraft\_retail_\Interface\AddOns\
```

Restart the game or run `/reload`, then enable **KIC LFG Greeter** in the
AddOns list.

## Testing

Join a party while the addon is enabled. About one second after joining, the
addon sends `hi` to the group's chat channel.
