-- Story content. Drafted from the README premise (see BLOCKED.md item 2); edit freely.
-- A dialogue is a list of lines {speaker = "...", text = "..."}. The last line may
-- carry choices {id, text, requires = flag}; choices whose flag is not set are hidden.
local Story = {}

Story.intro = {
    {text = "Ten years ago the explorer Mara Solis flew into the dark and never came back."},
    {text = "The Void Collapse had already swallowed half the settled worlds. People said she went looking for a way to stop it."},
    {text = "You grew up under another name, on a quiet world far from her star map. She made sure nobody could find you."},
    {text = "This morning a courier drone found you. It carried the access key to her ship, her star map, and three words: Find the Arkadia."},
    {text = "Her ship followed it down, flying itself. The cockpit was empty."},
    {text = "The Arkadia is a story spacers tell: a ship that can bring dead planets back to life and push the Void back."},
    {text = "Your mother's map says it is real. Her ship has set you down on Kepler Reach, where she made her first camp. First, learn to survive out here."}
}

Story.afterTutorial = {
    {speaker = "Ship computer", text = "Incoming message relayed from Drift Station. Sender: Quill. It reads: Come and see me, little Solis."},
    {speaker = "Ship computer", text = "Walk back to the ship and press E to open the star map. Drift Station is within jump range."}
}

Story.quillFirst = {
    {speaker = "Quill", text = "Ah. You have her eyes. And her ship. I am Quill. I kept this station running for Mara, and I kept her secrets."},
    {speaker = "Quill", text = "That map is incomplete on purpose. She split the Arkadia's coordinates into three fragments and sealed them in vaults on Cinder, Glacius and Verdant Deep."},
    {speaker = "Quill", text = "The vault doors open only for the Solis key, and only in Solis hands. I tried once. They do not open for drones."},
    {speaker = "Quill", text = "She told me to wait. Not to follow her, not to look for you. If her ship ever came home, I was to help whoever it brought. And here you are."},
    {speaker = "Quill", text = "Bring salvage and alien essence to my terminal and it will fit you with better gear. You will need a stronger jump drive for the far worlds."},
    {speaker = "Quill", text = "And Void Shielding, before you go anywhere near the Rift. Start with Cinder. Mind the pirates."}
}

Story.quillTruth = {
    {speaker = "Quill", text = "All three fragments. She would be proud. There is one more thing she made me promise to keep until you had them."},
    {speaker = "Quill", text = "Mara did not die. She reached the Arkadia and sealed herself inside its core to hold the Rift shut. She may still be alive in there."},
    {speaker = "Quill", text = "The Arkadia needs two keepers: one at its heart to hold the Rift shut, one at the helm to wake it. She went alone, so all she could do was hold the door."},
    {speaker = "Quill", text = "Ten years she has held it. If her ship came home now, she is failing. The Rift is widening again."},
    {speaker = "Quill", text = "I came out of the Rift once, broken and empty. She found me and mended me. That is how she knew the ship was real. I owe her this."},
    {speaker = "Quill", text = "When you reach the ship, you will have a choice to make. Only you can make it."}
}

-- What Quill says on later visits, based on progress
function Story.quillHint(session)
    local count = session:fragmentCount()
    local text
    if count < 3 and not session:hasUpgrade("jump_drive") and count >= 1 then
        text = "Glacius and Verdant Deep are beyond your drive's reach. My terminal sells a Mk II jump drive."
    elseif count < 3 then
        text = ("You have %d of the three fragments. Follow the vault markers on each world."):format(count)
    elseif not session:hasUpgrade("void_shielding") then
        text = "The Rift will tear an unshielded hull apart. Buy the Void Shielding before you jump."
    else
        text = "You are ready. The Rift is waiting. Go and find her ship."
    end
    return {{speaker = "Quill", text = text}}
end

Story.varroContact = {
    {speaker = "Captain Varro", text = "So the Solis brat finally crawled out of hiding. This is my rock, kid. My crews, my vault."},
    {speaker = "Captain Varro", text = "I watched your mother open that vault ten years ago. Those doors only open for a Solis. I have been waiting a long time for another one."},
    {speaker = "Captain Varro", text = "Here is my offer. Share the Arkadia's coordinates when you have them, and my people leave you alone. Every world, every jump."},
    {speaker = "Captain Varro", text = "Refuse, and you shoot your way through every pirate between here and the Rift. Choose.",
        choices = {
            {id = "deal", text = "Deal. Your crews stand down."},
            {id = "refuse", text = "Never. The Arkadia is not yours."}
        }}
}

Story.varroDeal = {
    {speaker = "Captain Varro", text = "Smart. My crews will not touch you unless you start it. I will be listening when you find that ship."}
}

Story.varroRefuse = {
    {speaker = "Captain Varro", text = "Then you are just another wreck waiting to happen. Good hunting, Solis."}
}

-- Mara's logs, found with each fragment
Story.logs = {
    cinder = {
        {speaker = "Mara's log 31", text = "The pirates followed me to Cinder, so I hid the first fragment right under their noses. Varro thinks the Arkadia is a weapon. It is a cure."}
    },
    glacius = {
        {speaker = "Mara's log 44", text = "The crystals here remember sound. I tuned the vault so only someone patient could open it. If that is you: I am sorry I left without saying goodbye."}
    },
    verdant_deep = {
        {speaker = "Mara's log 52", text = "The last fragment. The Rift is widening. If I reach the Arkadia and it cannot be steered, I will hold the door shut myself. Quill knows the rest."}
    }
}

Story.riftArrival = {
    {speaker = "Ship computer", text = "Void Shielding holding. Hull integrity stable. A very large vessel is drifting inside the Rift, three kilometres out."},
    {speaker = "Ship computer", text = "Rift readings are rising. It is widening."},
    {speaker = "Ship computer", text = "Expect heavy drone resistance. They are running on very old orders. They may stand down once your key reaches that ship."}
}

-- Added to the Rift arrival if the player refused Varro's deal
Story.riftVarro = {
    {speaker = "Ship computer", text = "Contacts behind us. Captain Varro's fleet is holding at the edge of the Rift. They are waiting for something."}
}

Story.arkadia = {
    {speaker = "Arkadia", text = "Access key recognised. Solis lineage confirmed. Defence drones standing down. Welcome aboard."},
    {speaker = "Mara (recording)", text = "If you are hearing this, you found it. The Arkadia can heal every world the Void took, but someone has to stay at its heart and hold the Rift shut while it works."},
    {speaker = "Mara (recording)", text = "The helm will answer you. The heart is mine, for as long as I can hold it."},
    {speaker = "Mara (recording)", text = "I have held it as long as I could. The choice is yours now.",
        choices = {
            {id = "dawn", text = "Wake the Arkadia and heal the galaxy."},
            {id = "legacy", text = "Free Mara from the core and take her place.", requires = "mara_alive_clue"},
            {id = "tyrant", text = "Hand the Arkadia to Captain Varro.", requires = "pirate_deal"}
        }}
}

Story.endings = {
    dawn = {
        title = "Dawn of Arkadia",
        text = "The Arkadia wakes. Its engines sing, and the Rift folds shut behind it like a healing wound. "
            .. "World by world, the dead planets turn green again. Your mother sleeps on in the ship's core, holding the last of the Void at bay, "
            .. "and you stand at the helm she left you. The galaxy has a future again.",
        defiedVarro = "At the edge of the Rift, Varro's fleet scatters as the Arkadia's engines wake."
    },
    legacy = {
        title = "The Keeper's Child",
        text = "You open the core. Mara stumbles out into your arms, older and thinner and alive. She takes the helm just long enough to wake the ship. Then you take her place. "
            .. "As the Arkadia heals the galaxy, you hold the Rift shut from its heart, dreaming of green worlds. "
            .. "Quill flies Mara home. She visits the ship every year, and tells you everything you missed.",
        defiedVarro = "At the edge of the Rift, Varro's fleet scatters as the Arkadia's engines wake."
    },
    tyrant = {
        title = "Varro's Crown",
        text = "Varro's fleet arrives within the hour. He thanks you, then turns the Arkadia's engines from healing to burning. "
            .. "Within a year every world flies his colours or does not fly at all. In the ship's core your mother keeps holding the Rift shut, "
            .. "for a galaxy that has forgotten her name."
    }
}

return Story
