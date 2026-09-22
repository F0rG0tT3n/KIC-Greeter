local _, KIC = ...

KIC.DEFAULT_GREETINGS = {
    { text = "Hi!", enabled = true },
    { text = "Hello!", enabled = true },
    { text = "Hey!", enabled = true },
    { text = "o7", enabled = true },
    { text = "o/", enabled = true },
    { text = "Greetings, fellow key enjoyers!", enabled = false },
    {
        text = "Hey team, I brought damage and questionable decisions.",
        enabled = false,
    },
    {
        text = "Yo! I’m here to press buttons and trust the healer.",
        enabled = false,
    },
    {
        text = "Hello! Let’s time this key before my food buff expires IRL.",
        enabled = false,
    },
    {
        text = "o/ Ready to turn this key into a highlight clip.",
        enabled = false,
    },
}

KIC.DEFAULT_TIMED_GREETINGS = {
    { text = "GG!", enabled = true },
    { text = "GGGGG!", enabled = true },
    { text = "Clean key, team!", enabled = false },
    { text = "Huge W, gamers.", enabled = false },
    { text = "Timer defeated, loot pending.", enabled = false },
    { text = "We actually cooked.", enabled = false },
    { text = "That key got absolutely deleted.", enabled = false },
    { text = "GG, healer deserves a vacation.", enabled = false },
    { text = "Smooth run! I only panicked twice.", enabled = false },
    { text = "We came, we kicked, we timed.", enabled = false },
}

KIC.DEFAULT_ABANDON_GREETINGS = {
    { text = "GG, we gave it a shot!", enabled = true },
    { text = "RIP key, you fought bravely.", enabled = true },
    { text = "The timer won this round.", enabled = true },
    { text = "Key bricked, vibes intact.", enabled = false },
    { text = "That was a learning experience. Probably.", enabled = false },
    { text = "We go next, gamers. o7", enabled = false },
    {
        text = "The real loot was the friends we made before disbanding.",
        enabled = false,
    },
    { text = "GG, this key had other plans.", enabled = false },
    {
        text = "We didn’t time it, but we definitely experienced it.",
        enabled = false,
    },
    { text = "Let’s pretend that was a practice run.", enabled = false },
}
