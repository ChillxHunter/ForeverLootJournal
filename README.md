# Forever Loot Journal

World of Warcraft: Forever | Interface 16001 | Addon v1.1.0

INSTALL
-------
1. Close World of Warcraft entirely.
2. On this GitHub page, click Code > Download ZIP, then extract it.
3. Rename the extracted ForeverLootJournal-main folder to ForeverLootJournal, then copy it to:
     World of Warcraft\_forever_\Interface\AddOns\
   so that the full file path is:
     ...\Interface\AddOns\ForeverLootJournal\ForeverLootJournal.toc
4. Relaunch Forever and enable the addon in the AddOns menu.
5. Type /flj in chat or left-click the round chest icon beside the minimap.
6. Hold Alt and drag the chest icon to reposition it around the minimap.
7. Your minimap icon position is saved automatically between sessions.

FEATURES
--------
* Account-wide persistent record of armor/weapons seen in loot chat while
  acquired by you or a current party/raid member.
* Observes native C_LootHistory updates and saves Need/Greed/Pass (and
  other modern roll states), individual numeric rolls and winning player
  where the game supplies this information.
* Receipts from loot messages are merged into matching roll records when
  identifiable, to avoid duplicate lines.
* Search loot by item name, player or zone; filter armor vs weapons.
* Search all previously grouped players, including players currently grouped.
* Choose a player to filter the loot archive. This includes drops they
  participated in as well as items they won.
* Stores known player name, character level, class, race, guild and encounter
  location from the time they were visible in your group roster.
* Inspect an item with its game icon, quality, item level, available stats,
  complete game tooltip on hover and Shift-click-to-chat item hyperlink.
* Mousewheel scrolls group history, item list and roll list.
* Automatically limits the archive to the newest 5,000 records to avoid
  unbounded SavedVariables growth. Clearing the log is optional.

COMMANDS
--------
/flj                 Open or close the journal
/flj players         Open journal and focus player search
/flj refresh         Refresh group roster and available loot rolls
/flj clear           Request confirmation to delete saved loot
/flj help            Show command help
/flj showicon        Show the minimap button
/flj hideicon        Hide the minimap button
/flj icon            Toggle the minimap button
/flj reseticon       Reset minimap button position to the default location

IMPORTANT LIMITATIONS
---------------------
- Begins logging only after installation, while the addon is enabled.
- Can log only information exposed to your client by World of Warcraft.
  There is NO cross-player telemetry, chat snooping, or historical API.
- Need, Greed, Pass and numerical results are available only when Forever's
  native Loot History API exposes the group roll. A normal loot message
  provides the winner/item but not the rolls.
- The client may not expose every transfer, trade, master-loot allocation,
  or exact outcome. Such records can have incomplete winner/roll data.
- Player character metadata is what your group roster exposed during a
  session; guilds, levels and class may be missing or become outdated.
- Item stats are selected values from C_Item.GetItemStats. The full in-game
  item tooltip is available by hovering its icon; tooltip text is not stored.
- The Lua code was syntax-checked and smoke-tested with mocked WoW events.
  It has not yet been tested inside a live Forever client.
- Blizzard may change the Forever Interface build in a future update.

MAINTENANCE
-----------
Records are stored by the client in account SavedVariables:
  WTF\Account\<account>\SavedVariables\ForeverLootJournal.lua
Settings are written on logout or /reload. Keep backups when updating.

This addon has no outside network connections, tracking or data sharing.
The TGA header and parchment textures are original procedural UI assets.
Game item and class icons are loaded from World of Warcraft itself.

SOURCE AND RELEASE STATUS
-------------------------
This repository contains the addon source. It is not yet field-tested inside the live WoW Forever client; report Lua errors and client-version differences in GitHub Issues.

MINIMAP SHORTCUT
----------------
Left-click the round chest icon to open or close the journal. Alt-drag moves it around the minimap and remembers its position. If it is lost, type /flj reseticon.
