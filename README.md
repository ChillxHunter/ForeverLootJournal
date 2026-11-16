# Forever Loot Journal

## Version 1.4.0 - visible fantasy header and clearer journal

- Fixes the opaque child panel that covered the title, custom banner and gold frame. The background now uses root textures, preserving the intended draw order.
- Fixes rarity checkmarks being drawn behind their own checkbox backgrounds.
- Uses clean body text, navy panels throughout Loot and Crafting, better item-detail spacing, and six compact loot rows instead of four.
- Adds visible paging buttons for loot and players, record ranges, account totals, and an **All rarities / Rare+ / Epic+** archive filter. This viewing filter never changes rarity registration or deletes records.
- Correctly highlights the initial item and rounds decimal stats to two places. Viewing rolls sorts a copy and leaves the recorded order intact.
- Removes the native edit-box artwork that conflicted with the custom search fields. Settings cards fit within their panels.

**Install:** Close WoW, extract the ZIP into `_forever_/Interface/AddOns/`, and replace the existing `ForeverLootJournal` folder. Keep your `WTF` folder to retain loot, players, recipes and preferences. Open with `/flj`; use the gear button for Settings.

**Validation:** Existing addon tests plus regressions for header/checkmark layering, six-row display, selection, decimal stats and non-destructive rarity filtering. Layout previews are exported from actual addon widget construction with sample records; built-in game icons and fonts are approximated. Final appearance must be checked inside WoW Forever.

## Version 1.3.0 – full D-style modern World of Warcraft redesign

This release rebuilds the **actual in-game addon interface** around the selected **Design D** mockup, not a standalone image.

**New look:**
- Custom dark-navy fantasy castle header with gold framing, improved spacing and compact top-right settings button.
- The journal uses dark blue panels, cool metallic borders and gold active-tab highlights instead of the old beige/parchment textures.
- **Settings** is an interactive screen with a left menu: **General, Rarity Filter, Storage, Display, Profiles**.
- The **General** page matches the chosen mockup with eight rarity-toggle cards above five PC-capacity cards. Colored boxes indicate which qualities are saved.
- **Rarity Filter** and **Storage** have dedicated explanations; **Display** controls player class colors, item hover tooltips and live group indicators; **Profiles** shows saved records, recipes and group statistics.
- The five existing saved-item presets work from the cards: **Potato 1,000**, **Normal 2,000**, **Strong 3,000**, **MONSTER 5,000**, **EXTREME!! 10,000**. Lowering your limit still requires confirmation before old records are removed.
- Rarity switches still affect **new loot only**. Already recorded items are neither removed nor hidden by rarity settings.
- Loot searching, group-roll details, Crafting, cross-zone party synchronization, and right-click player actions remain available in the main journal.
- Opening and closing Settings only changes presentation; existing `ForeverLootJournalDB` data is preserved.

**How to use:** Enter `/flj`, click the **gear icon** in the top-right corner, then select **General** or a dedicated settings page. **Back to Journal** returns to the original loot, players and crafting views.

**Download:** [Forever Loot Journal v1.3.0 installable ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.3.0/ForeverLootJournal.zip). It extracts directly to `ForeverLootJournal/` without the `-main` suffix. Exit WoW, replace the previous addon folder and keep the `WTF` SavedVariables directory to preserve your history.

**Validation:** A Lua 5.1 UI simulation creates the actual window and settings controls, activates rarity/profile/display settings, checks the reduction-confirmation dialog, and returns to the journal. Actual rendering and texture/font sizing must still be checked inside WoW Forever.


## Version 1.2.7 – fixed repeat Ignore requests and "Saint Ramz" display mismatch

- Matches WoW's server message name `Saint Ramz` to the journal's `Saint-Ramz`, without matching two different explicit realms.
- When the game confirms `is now being ignored`, the right-click menu uses that verified response to display **Unblock Player**, even if the Ignore-list API has not updated yet.
- Prevents another Block request while a previous Ignore action is awaiting the server response.
- Stops sending `ShowFriends` refresh requests on every menu opening or every Block/Unblock click. Friends data still refreshes on login and when explicitly requested.
- Still uses WoW's real Ignore list. No local permanent block database has been added.
- Expanded Lua 5.1 regression tests cover async game confirmation, pending requests, and variants with spaces/hyphens.
- `/flj ignorestatus Saint-Ramz` remains available if the game still returns inconsistent Ignore-list data.

**Install:** [Download the v1.2.7 ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.2.7/ForeverLootJournal.zip), which extracts directly into `ForeverLootJournal/` without `-main`. Exit WoW, replace the old addon folder, and restart. Existing loot records and settings remain intact.


## Version 1.2.6 – fix previously ignored players still showing Block

- Requests up-to-date WoW friend/ignore information after login, and checks the actual Ignore list whenever the right-click player menu opens.
- Checks all supported ignore-status APIs rather than relying on a single function that might be missing in WoW Forever.
- For already ignored players, displays **Unblock Player** and removes the **exact existing Ignore-list entry by index** when supported.
- When the game cannot verify an ignore status, shows **Refresh Ignore Status** rather than sending a potentially duplicate Block request.
- The addon's local loot and player history is unchanged. There is no separate addon-side block database.
- If the game still misreports an existing block, enter `/flj ignorestatus Character-Realm` (for example `/flj ignorestatus Saint-Ramz`) and share the printed diagnostics.

**Install:** [Download v1.2.6](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.2.6/ForeverLootJournal.zip) from GitHub Releases, extracting to `ForeverLootJournal/` with no `-main` folder. Close WoW, replace the previous addon folder, and restart.


## v1.2.5 – correctly show Unblock Player for ignored characters

When you right-click a character in the Party & Raid Members list, the Block option now checks **WoW's existing Ignore list**. If the character is already ignored, the menu displays **Unblock Player**. Clicking it removes the matching name from the actual Ignore list.

This also handles the common situation where WoW stores an ignored player under a short character name but the journal displays `Name-Realm`. The addon will not confuse characters from two different explicitly named realms. Your saved loot and player history are unchanged.

**Install:** [Forever Loot Journal v1.2.5 ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.2.5/ForeverLootJournal.zip) extracts to `ForeverLootJournal/` without `-main`. Exit WoW, replace the previous addon directory, then restart.


## Version 1.2.4 – right-click player actions

**New:** Right-click any player in the **Party & Raid Members** list to open a WoW-native context menu with:

- **Whisper** – opens a private chat with that character
- **Add Friend** – adds the character to your WoW friends list; shows Already Friends when applicable
- **Block Player (Ignore)** / **Unblock Player (Unignore)** – adds or removes the character from WoW's actual Ignore list (not an addon-only block)
- **Invite to Party** – sends the WoW party invitation, when permitted and the person is not already grouped
- **Invite to Guild** – sends a guild invitation when you are in a guild and have invite permissions

**Left-click still filters loot by player.** Mouse-over hints explain the different clicks. The native menu uses a direct player click for guild invitations, which WoW protects with a hardware-event requirement.

WoW controls eligibility and whether the target receives or accepts invitations. Cross-realm invites can be restricted by the game. If your game client lacks the modern context-menu framework, the addon reports that the menu is unavailable instead of breaking the player list.

**Install:** [Download v1.2.4 ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.2.4/ForeverLootJournal.zip) from GitHub Releases, containing the correctly named `ForeverLootJournal/` folder (no `-main` suffix). Exit WoW and replace the old addon folder; your SavedVariables loot history stays intact.


## Version 1.2.3 – minimap icon matches other addon markers

- Replaces the oversized bright-orange icon with a compact **dark, circular treasure-chest button** and subtle bronze/gold trim, matching the appearance of nearby minimap addon buttons.
- Changes the physical button size to **30×30** instead of 34×34 and uses the same **MEDIUM** frame strata as Forever Casino.
- Places it near the minimap rim using the map's actual width, removing the previous excessive outside offset.
- Dragging adjusts the position around the map and allows small inward/outward placement changes; both values persist.
- `/flj reseticon` resets both angle and rim distance. Existing saved records and preferences are unaffected.
- Installs from the [v1.2.3 release ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.2.3/ForeverLootJournal.zip), which extracts to `ForeverLootJournal/` without `-main`.


## Version 1.2.2 – choose which loot rarities to register

A row of **SAVE NEW LOOT** buttons is displayed at the top of the journal, beneath the heading and beside the saved-loot PC preset. Click each rarity to switch it **ON** or **OFF**:

**Poor • Common • Uncommon • Rare • Epic • Legendary • Artifact • Heirloom**

- **ON:** future drops of that rarity are recorded.
- **OFF:** future drops of that rarity are not registered in this player's archive.
- All eight rarities are **ON by default**, preserving existing behavior.
- Preferences persist account-wide in `ForeverLootJournalDB.ui.rarityRegistration`.
- **Previously saved records are never deleted or hidden when a rarity is turned off.** You can enable it again later without affecting history.
- Applies to new equipment, recipe items, locally observed group rolls and cross-zone loot shared through the addon.
- Learned crafting recipes in the profession catalog are tracked separately and are **not** affected by loot rarity filters.
- The item-quality filter uses WoW's quality data. When an item's rarity has not loaded yet, the addon requests the item data and waits rather than assuming it is Common.

To configure: open `/flj` and click the quality buttons at the top of the main window. The bright underline and **ON** label mean a rarity will be saved; **OFF** means new items of that quality will be skipped.

**Install:** [Download v1.2.2 ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.2.2/ForeverLootJournal.zip). Extract into `Interface/AddOns` as `ForeverLootJournal/` (no `-main`). Close WoW before replacing the old folder; leave the `WTF` SavedVariables unchanged to keep your history.


## Version 1.2.1 – Crafting recipe tab

A new **Crafting** tab is available beside All Equipment, Armor, and Weapons.

- **Learned recipes:** Open a character's crafting/profession window at least once. The addon scans learned recipes from that profession and saves them in an account-wide catalog, including profession, recipe name, icon, known characters, and ingredients where WoW makes those available.
- **Looted recipes:** Recipe scrolls, blueprints, and formula items are now tracked in the group loot log (WoW item class 9) and shown under Crafting, including the recipient and zone. Group sync also recognizes recipe drops when other party members run the updated addon.
- **Search:** Search the Crafting tab by recipe name, profession, material, or character. Scroll its recipe list and ingredients.
- **Stored separately:** Learned crafting recipes are saved as `ForeverLootJournalDB.recipes`, outside the 1,000–10,000 equipment-loot caps. Looted recipe *items* remain loot records and count toward that configured limit.
- **Reopen each profession** to populate that character's known recipes. This does not download an entire database of unlearned World of Warcraft recipes; it records learned recipes your client exposes.

The new recipe catalog will remain available on this account when the profession window closes, and can include multiple characters. Exact reagent availability depends on item cache and the trade-skill API supported by WoW Forever.

**Install:** [Download v1.2.1](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.2.1/ForeverLootJournal.zip) — ZIP extracts directly to `ForeverLootJournal/` without `-main`. Close WoW and replace the previous addon directory; do not delete your SavedVariables.


## Version 1.2.0 – saved-loot capacity presets

A **SAVED LOOT LIMIT** dropdown now appears in the top-right header of the journal. Select your computer's preferred saved-item capacity:

| Preset | Maximum loot records |
|---|---:|
| Potato PC | 1,000 |
| Normal PC | 2,000 |
| Strong PC | 3,000 |
| MONSTER PC | 5,000 |
| EXTREME!! | 10,000 |

The selected preset is saved account-wide in SavedVariables. The default for existing users is **MONSTER PC (5,000)**, matching the old limit and preserving current loot on upgrade. The limit applies to *loot records*, not to the separate known-player list.

**Changing to a lower limit:** If you have more records than the new maximum, WoW will ask for confirmation before permanently deleting the oldest records. If you cancel, no records or settings are changed. Changing to a higher limit never deletes records; previously deleted records cannot be recovered unless backed up elsewhere.

New loot automatically removes the oldest record after the selected capacity has been reached. The five presets do **not** guarantee a particular FPS: 10,000 fully populated loot/roll records can require more memory and search time.

**Install:** [Download the installable v1.2.0 ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.2.0/ForeverLootJournal.zip) which contains `ForeverLootJournal/` (without `-main`). Close WoW, replace the old addon folder, and keep your `WTF` SavedVariables intact.


## v1.1.9 – cross-zone party and raid loot synchronization

**New:** When two or more party/raid members run Forever Loot Journal v1.1.9, the addon can send newly looted armor and weapons to other members over WoW's built-in addon communication channel. It works even when the characters are in **different zones, maps, or instances**, as long as the game allows party/raid addon messages between them.

- Each player shares **their own** newly received equipment; it does not read distant players' inventory.
- Receivers record the item's unique item string, owner, zone, equipment type, and available equipment stats. Item tooltips may take time to populate if the receiver has not cached the item.
- Repeated addon transmissions are deduplicated, and only current party/raid members' messages are accepted.
- Nearby members without the addon can still be recorded through ordinary local loot messages; **distant players without the addon cannot be tracked reliably**.
- Only gear looted **after** both players have installed the addon and are grouped can be shared; existing history is not automatically retrieved.
- Group roll numbers/choices are still recorded only when the normal loot history is visible on your own client; remote loot sync does **not** guarantee another player's full roll history.
- Sync is enabled by default for grouped characters and can be disabled at any time.

**Commands:** `/flj sync` or `/flj sync status` shows the sync state, channel, and recently detected addon users. `/flj sync check` asks the group to announce the addon. `/flj sync off` or `/flj sync on` turns sharing off or on.

**Testing:** Have both players install v1.1.9, join the same party, stand in different zones, use `/flj sync check` and then loot a weapon or armor item. On the other character, open `/flj` and check the archived records.

**Install:** Download the [v1.1.9 installable ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.1.9/ForeverLootJournal.zip), which extracts into `ForeverLootJournal/` without `-main`. Exit WoW before replacing the old addon directory. Leave the `WTF` SavedVariables untouched to keep your saved log.


## Version 1.1.8 – fixed circular minimap icon and outside positioning

- Fixed the icon being square: added a custom **32-bit TGA** with transparent corners and an integrated circular gold rim.
- Fixed the icon being inside the minimap: its radius now follows the minimap's actual width, with a minimum offset beyond the map border.
- Uses the working Casino-style player-login initialization and drag mechanism.
- Minimap icon position resets once after upgrading to this version; your later manual placement remains saved.
- **Left-click** opens the journal, **drag** moves the icon around the minimap, and `/flj reseticon` restores its outside position.
- GitHub's automated tests check that the icon's corners are transparent and that positioning remains outside the map during drag.

**Install:** Download the [v1.1.8 installable ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/download/v1.1.8/ForeverLootJournal.zip). It extracts to `ForeverLootJournal/` without `-main`. Close WoW and replace the addon folder; don't delete SavedVariables.


## Version 1.1.7 – Casino-style minimap recovery and AddOns tooltip commands

The minimap launcher now follows the **working Forever Casino button implementation**: it is created at player login, parented to the minimap, uses Blizzard's native tracking border texture, and is repositioned by dragging. Earlier versions that created it immediately when the addon loaded could fail to show the icon. Existing saved icon settings are reset once on upgrading to v1.1.7.

**In-game controls:** Left-click the round chest icon to open/close the journal. Drag to reposition it and save its angle. If it is missing, try `/flj reseticon` or `/flj iconstatus`.

**The AddOns tooltip now shows these commands:** `/flj`, `/foreverloot`, `/flj players`, `/flj refresh`, `/flj clear`, `/flj showicon`, `/flj hideicon`, `/flj reseticon`, `/flj iconstatus`, and `/flj help`.

**For installation:** Use the [latest Release ZIP](https://github.com/ChillxHunter/ForeverLootJournal/releases/latest/download/ForeverLootJournal.zip) rather than GitHub's *Code > Download ZIP*. It extracts to `ForeverLootJournal/` without the `-main` suffix. Close WoW before replacing your old addon folder; do not delete your `WTF` SavedVariables.


## Version 1.1.6 – minimap visibility and ZIP folder fix

- Restored the round minimap chest icon with a simpler implementation that is not clipped by the minimap.
- Migrates saved minimap settings once so the previously missing icon is visible again.
- Left-click opens the journal; left-drag moves the icon around the minimap; the angle persists.
- No square black background or potentially incompatible circular masks.
- The new packaged ZIP extracts to **ForeverLootJournal/** directly. Do not use GitHub's default "Code > Download ZIP" if you want to avoid "ForeverLootJournal-main".
- `/flj reseticon` moves a missing icon to its default location, and `/flj iconstatus` reports visibility state.

**Preferred download:** [ForeverLootJournal.zip from the latest Release](https://github.com/ChillxHunter/ForeverLootJournal/releases/latest/download/ForeverLootJournal.zip).


## Version 1.1.5 – minimap recovery and expanded item details

- Restores the minimap marker for users whose previous version hid or misplaced it. A one-time position reset moves the marker to the lower-right edge.
- Replaces masked minimap rendering with a standard circular gold-rimmed button; no square black backdrop.
- Drag the marker with the left mouse button to position it around the minimap. The position persists.
- Adds `/flj iconstatus` to diagnose visibility and `/flj reseticon` to restore it.
- Enlarges the item details and roll history panel to show **six item/stat lines and nine roll participants** at once.
- Grows the journal vertically, scales to fit the screen, and positions it slightly higher when room is available.
- Preserves account-wide loot logs and the other v1.1.4 fixes.

**Install:** Close WoW completely, replace the old `Interface/AddOns/ForeverLootJournal` folder with the new GitHub ZIP's `ForeverLootJournal-main` folder renamed to `ForeverLootJournal`. Do **not** delete the `WTF` SavedVariables file. Restart WoW.


## Version 1.1.4 – equipment filtering and minimap fixes

- Armor, Weapons, and All Equipment buttons now register clicks explicitly, show an active indicator, and update the matching-item count.
- Journal dragging is confined to the title bar so it doesn't capture button clicks.
- The item-details selection follows the active equipment filter rather than showing an excluded item.
- Existing records missing their equipment-class ID are reclassified when item data is available.
- Minimap launcher now uses a circular-masked icon, no opaque square backdrop, and stays outside the minimap. Drag it to reposition; `/flj reseticon` restores its position.
- Corrected possible loot winner tally changes and ambiguous duplicate record matching.
- All saved loot history remains in SavedVariables.

## Previous: version 1.1.2 – screen-fit and portrait fixes

- Journal scales to fit the available screen height and width, including the full item-details panel and footer.
- Footer now has a separate bottom panel so its text is not covered by the item-details panel.
- Live party/raid members show character portraits; previously grouped members use class portraits.
- Missing glyph squares replaced with game UI textures or supported text.
- Existing minimap button and Alt-drag controls remain unchanged.

**To update:** Download the latest GitHub ZIP, completely close WoW, replace the old `ForeverLootJournal` addon directory (not your `WTF` saved settings), then relaunch.


World of Warcraft: Forever | Interface 16001 | Addon v1.2.0

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
6. Drag the chest icon with the left mouse button to reposition it around the minimap.
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

