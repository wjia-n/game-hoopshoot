# Hoop Shoot — Rules

Authoritative rules for Hoop Shoot. If the implementation conflicts with this
document, the implementation is wrong and must be fixed.

## 1. Objective
Score as many points as possible by shooting a basketball through the hoop.
Swishes (nothing but net) score 3 points; baskets that touch the rim score
2 points.

## 2. Setup
- One human player (Shot Clock, Streak, Endless) or two human players
  (Shootout, pass-and-play on one device).
- The player picks a mode and a difficulty tier (Rookie / Street / All-Star).
- Each shot starts with the ball at a resting spot near the bottom of the
  court and the hoop at the top. The ball is shot by flicking up.

## 3. Turn order
- Solo modes: the player shoots repeatedly until the mode's end condition.
- Shootout: the two players strictly alternate shots, Player 1 first.
  Each player takes 5 shots. If the score is tied after 5 each, sudden-death
  pairs are played until one player leads after a completed pair.

## 4. Legal moves
- Flicking up on the ball (an upward swipe released with enough speed)
  launches the shot. Flicks must have upward velocity: downward or weak
  gestures are ignored, not penalized.
- A shot in flight may touch the rim and the backboard.

## 5. Illegal moves
- Flicking while a ball is already in the air does nothing.
- Flicking while the game is paused, over, or before a mode starts does
  nothing.
- There is no way to move the ball other than a legal flick.

## 6. Captures
N/A — no captures in Hoop Shoot.

## 7. Special rules
- **Swish detection:** the ball must cross the rim plane moving downward
  with its center inside the rim, having touched nothing (no rim, no
  backboard) since release. Worth 3 points.
- **Rim-in:** a basket where the ball touched the rim (or backboard) before
  crossing the plane is worth 2 points.
- **Shot-clock buzzer:** a ball released before the clock expires counts if
  it scores (the "in the air" rule). The game ends when the ball settles.
- **Wind:** on Street difficulty and above, gusts push the ball in flight.
  The HUD shows wind direction and strength.
- **Moving hoop:** on Street difficulty and above, the hoop slides sideways
  following a smooth sine. It never leaves the court's playable width.
- **3-strike rule (Endless):** three consecutive misses end the run.

## 8. Scoring
- Swish = 3 points. Rim-in = 2 points. Miss = 0.
- Streak bonus messaging: 3+ consecutive swishes show "ON FIRE".
- Points, baskets, swishes, and shots are tracked per game.

## 9. Winning conditions
- Shot Clock: highest score when the clock expires wins (solo: beat your
  best).
- Streak: highest score after 10 balls.
- Endless: highest score before 3 consecutive misses.
- Shootout: the player with the higher score after 5 shots each, or after
  sudden death, wins. Sudden death cannot end tied: pairs continue until
  the scores differ.

## 10. Draw conditions
- Solo modes have no draws; the score stands against the player's best.
- Shootout never draws: sudden death continues until one player leads.

## 11. AI strategy
N/A — Hoop Shoot has no bots. (Shootout is human vs human pass-and-play.)

## 12. Edge cases
- Ball exactly on the rim edge: physics resolves via rim-tip collision;
  a crossing within the rim minus ball radius still counts.
- Flick released exactly at the buzzer: if the ball left the hand before
  expiry, it counts.
- App backgrounded mid-flight: the engine pauses; on resume the shot
  continues from the frozen state.
- Watchdog: a ball in flight longer than 6 seconds, or a settle phase
  longer than 3 seconds, is forced forward — the game can never hang.

## 13. Test cases
1. Flick up hard → ball flies, shot counted once.
2. Flick down/weak → ignored, no shot counted.
3. Double-flick mid-flight → second flick ignored.
4. Swish straight through → +3, net snap, "SWISH!" popup.
5. Rim touch then in → +2, "Rattled in!" popup.
6. Ball flies off-screen → miss quip shown, next ball arrives.
7. Clock hits 0 mid-flight → buzzer, shot counts, then game over.
8. Clock hits 0 with ball ready → game over immediately.
9. Streak: 10 shots → game over with X/10 buckets.
10. Endless: 3 consecutive misses → game over.
11. Shootout: 5 shots each, alternating, winner named; tie → sudden death.
12. Pause mid-flight → ball frozen; resume → shot continues.
13. Background/foreground → music resumes, no stuck state.
