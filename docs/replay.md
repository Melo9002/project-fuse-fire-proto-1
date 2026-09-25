# Battle replay

Fuse Fire records successful authoritative actions during a battle. When the battle
ends, **Replay Battle** rebuilds the same seeded match and submits those actions through
the ordinary gameplay APIs. **Return to Match Setup** starts a blank setup screen.

## Recorded information

The in-memory `BattleReplayRecording` contains the complete battle configuration and an
ordered action list. Each action identifies its actor, round, and phase. It also carries
an authoritative post-action fingerprint containing the phase, active unit, battle
result, every remaining unit's cell, HP, AP, defense and carried actor, objective
progress, and extraction totals. Depending on
the action, it also records movement cells, an attack target and outcome, a rescue
target, extraction, defense, or a phase advance.

The main participants are:

- `BattleReplayRecorder`: observes successful actions without choosing or executing them.
- `BattleReplaySession`: retains the latest completed battle while the game is running.
- `BattleReplayPlayer`: rebuilds the match, disables normal input and AI, and executes the log.
- `BattleLevel`: creates the recorder or player and owns the end-screen navigation.

Movement, attacks, defense, rescue, extraction, and turn advancement still use
`BattleController`, `ObjectiveManager`, and `TurnManager`. Replay therefore detects
rule or determinism drift instead of concealing it with a visual-only reenactment.

## Testing

Play any battle through victory or defeat. The result UI should expose both buttons.
Press **Replay Battle** and confirm the HUD says `REPLAY`, the same map and actors are
created, ordinary controls stay disabled, and the same result is reached. The console
prints the number of recorded actions followed by `COMPLETED` or `DIVERGED`.
`COMPLETED` also reports how many action fingerprints matched. A mismatch prints the
first divergent action plus its expected and actual states.

Run the automated end-to-end check with:

```powershell
godot_console --headless --path . --script res://tests/battle_replay_smoke.gd
```

## Current boundary

The recording currently lives in memory and replays at turn-based action timing with
the ordinary tactical camera. It is the data and execution foundation for later saved
replay files, playback speed controls, pseudo real-time timing, a unit-follow camera,
and a camera mode that cuts only to the final mover in an activation.
