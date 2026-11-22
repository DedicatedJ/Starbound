---
type: index
status: draft
tags:
  - lore/index
---

# Game Changes Needed

The [[Story Spine]] closes the plot holes in the lore, but players only see what the game says. These are the smallest changes to the game text (`src/data/story.lua`, plus two small code hooks) that would put the fixes on screen. Nothing here has been made yet.

| # | Where | Change | Closes |
|---|---|---|---|
| 1 | `Story.intro` | Add that the ship arrived empty, flying itself, and that it brought you to Kepler Reach, where your mother first made camp | How the ship got back; why Kepler Reach |
| 2 | `Story.quillFirst` | Quill: the vaults open only for the Solis key, Quill cannot open them, and Mara told it to wait for her ship | Quill's ten-year wait; who the vaults keep out |
| 3 | `Story.quillFirst` | Quill hints at its origin: "I came out of the Rift, the way she went in" | What Quill is |
| 4 | `Story.varroContact` | Varro: "I watched your mother open that door. Only a Solis can." | How Varro knows; why he needs the player |
| 5 | `Story.quillTruth` | Add the heart and the helm, and that Mara is failing and the Rift is widening again | Why nothing healed; why now |
| 6 | `Story.riftArrival` | Ship computer reads the Rift widening. If the player refused Varro: "Varro's fleet is holding at the Rift's edge" | Urgency; Varro's payoff |
| 7 | `Story.riftArrival` | Ship computer: the drones run on old orders and will stand down once the key docks | Why the Arkadia's drones attack its heir |
| 8 | `Story.arkadia` | Mara's recording: "The helm will answer you. The heart is mine, for as long as I can hold it." | The two stations |
| 9 | `Story.endings.legacy` | One line: Mara takes the helm long enough to wake the ship before Quill flies her home | Who wakes the ship in that ending |
| 10 | `Story.endings.dawn` and `.legacy` | If the player refused Varro: his fleet scatters when the Arkadia wakes | Varro's payoff |
| 11 | Vault doors (`src/world/vault.lua`) | When the player reaches a vault door: "The door reads your key." | Who the vaults keep out |

Lines 6 and 10 need the game to check the `pirate_deal` flag, which it already tracks.

## Optional
- **Dawn ending without the truth.** A player can reach the Rift without talking to [[Quill]] after the third fragment, which is when the game reveals that Mara is alive. Their Dawn ending then calls her "sleeping" without them knowing she was there. Either make Quill's truth unmissable (trigger it when the player buys [[Void Shielding]]), or keep it as a reward for players who go back to Quill.
