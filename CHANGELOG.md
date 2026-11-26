---

### `CHANGELOG.md`

```markdown
## [0.0.7] - 2026-11-26

### Added
* **Added Profiles and per character setting and sessions. Will no longer carry sessions over to other characters. Profiles added to keep UI theming across multiiple characters/profiles

### Fixed
* Fixed the post button on the tracker
* Fixed left clicking on a log in the history UI

## Removed
* Removed repair costs and repairs calculated into profits. Just was not viable to try to keep track of


## [0.0.6] - 2026-11-23

### Added
* **Farm Finder (`/ft farms` or header map icon):** Added a live gold-per-hour browser that evaluates hourly item yields against your selected AH price source (TSM Min Buyout, Market, Historical, Auctionator, or Vendor).
* **Built-In Profession Farm Data (`Data\`):** Added pre-populated Classic/WoW Forever farming routes across **Mining**, **Herbalism**, **Skinning**, **Cloth**, and **Fishing**.
* **Save Runs from Session History (`+`):** Click the `+` button on any logged session in `/ft history` to convert its hourly coin and item yields into a custom Farm Finder entry with a chosen category and optional Routes string.
* **Custom Farm Import & Export (`FT1:...`):** Added **Import Farm** and **Share** buttons to export and share custom farming spots (including hourly yields and optional `RoutesImportExport` strings) via copyable text strings.
* **Continent Filters & Column Sorting:** Added continent filter buttons (**All Continents**, **Eastern Kingdoms**, **Kalimdor**), a **Custom** tab for player-created farms, and clickable ascending/descending column sorting by **Farm / Zone**, **Category**, and **Gold / Hr**.

### Changed
* Session History entries now snapshot individual non-blocked item counts when resetting a session so they can be promoted into Farm Finder entries.
* Changing the AH Price Source in Settings now updates open Farm Finder prices live.

### Fixed
* Fixed uncached items in Farm Finder displaying as `Item #ID` with `0c` until manually refreshed by listening for `GET_ITEM_INFO_RECEIVED`.
* Fixed a Lua table sort error (`attempt to index local 'b'`) when toggling ascending/descending column headers in Farm Finder.

## [0.0.5] - 2026-11-23

### Added
* **Tabbed Settings Menu:** Reorganized `/ft config` into 4 tabs (**Appearance**, **Display**, **Loot & AH**, and **Automation**) so the window stays compact.
* **Individual Blocklist Manager:** View and remove individual items from your Global Blocklist directly in the **Loot & AH** tab.
* **Drop Alert Sound Options:** Added a sound picker dropdown (Coins, Map Ping, Whisper, Ready Check, Quest Complete, Raid Warning) with instant previews, a **Mute Alert Sound** (flash banner only) checkbox, and a **Test** button in Settings.
* **Background Opacity & Click-Through:** Added an opacity slider (10%–100%) for the tracker and loot windows, plus an option to make Compact Mode click-through when locked.
* **Auto-Resume:** Added options to automatically resume the timer when clearing AFK, leaving a rested area, or entering combat (only triggers if the timer was auto-paused).
* **Key Bindings (`Bindings.xml`):** Added Farm Tracker bindings to WoW's Key Bindings menu for Toggle Window, Start/Pause, New Run, and Compact Mode.
* **Copy Summary (`Ctrl+C`):** Added a copyable text popup to the **Post** menu and made Session History rows clickable to copy past runs for Discord or spreadsheets.

### Changed
* Refactored `FarmTimer.lua` into smaller modules: `Core\Utils.lua`, `Modules\Pricing.lua`, `Modules\LootWindow.lua`, and `Modules\Tracker.lua`.
* Updated `History.lua` and `Options.lua` to use shared formatting and backdrop theming from `Utils.lua`.
* Reworked repair cost detection to match durability changes against gold spent, supporting manual repairs, single-item repairs, auto-repair addons, and repairs while paused in cities (still ignores guild bank repairs).

### Removed
* Removed `COMBAT_LOG_EVENT_UNFILTERED` tracking and the background mob kill counter.
* Removed duplicate code at the bottom of `VersionCheck.lua`.

### Fixed
* Fixed an `ADDON_ACTION_FORBIDDEN` error on login/reload caused by registering `COMBAT_LOG_EVENT_UNFILTERED`.
* Fixed repair costs staying stuck at `0c`.

## [0.0.4] - 2026-11-22

### Added
* **Session History Log (`/ft history` or header icon):** Automatically logs sessions over 10 seconds when you hit Reset (stores up to 50 sessions). Hovering a row shows the full breakdown, including repairs, XP, runs, and background mob kills.
* **XP / Hour & Time to Level (TTL):** Tracks session XP/hr and estimated time to next level. Both rows hide automatically at level 60.
* **Net Profit & Repair Tracking:** Tracks personal vendor repairs (including auto-repair addons, ignoring guild bank repairs) and factors them into Net Session Profit and Net Gold/Hr.
* **Loot Ignore & Global Blocklist:** Right-click any item in the Loot Window to ignore it for the current session or add it to a global blocklist.
* **High-Value Drop Alert:** Plays a coin sound and shows a brief on-screen flash banner when a drop meets or exceeds your configured threshold (defaults to `2g`; set to `0c` to alert on all drops). Added `/ft testalert` to preview it.
* **Configurable AH Price Source:** Added a dropdown in Settings to pick between Auto, TSM (Min Buyout, Market, Historical), Auctionator, or Vendor Only.
* **Free Bag Slots Counter:** Optional row that turns orange at 5 or fewer free slots and red when bags are full.
* **Auto-Pause:** Options to automatically pause the timer when flagging AFK or entering a city/rested area.
* **Session Gold Goal Bar:** Optional progress bar at the bottom of the tracker with a configurable gold target.
* **Compact Mode:** Header toggle (`-` / `+`) to collapse the tracker down to a single timer and GPH line.

### Changed
* Made TradeSkillMaster and Auctionator optional dependencies. If neither is installed, the tracker falls back to Vendor + Raw gold automatically.
* Font dropdown now pulls all locale-valid fonts from `LibSharedMedia-3.0` with a scrollbar.
* Settings window now dynamically resizes to fit its controls and closes when pressing `ESC`.

### Fixed
* Fixed blank font previews in the font dropdown for unavailable/missing font files.
* Clamped text inside the Font Family and AH Price Source buttons so long names no longer overflow the button borders.

## [0.0.3] - 2026-11-21
### Changed
* Renamed to just FarmTracker

### Removed
* Removed the hideRaidManager functionality completely

## [0.0.2] - 2026-11-20
### Added
* Collapsible loot window attached to the Farm Tracker with a quality filter (All, Common+, Uncommon+, Rare+, Epic+, Legendary+).
* Toggle to switch Session Total and Gold/Hr between AH + Raw Coin and Vendor + Raw Coin.
* In-game settings menu (`/ct config` or gear icon) with theme options (Dark Modern / WoW Forever), font dropdown, 8–64px font size slider, and toggles for individual stats.
* Drag-to-resize corner handle and a lock button to lock window position and size.
* Minimap button (Left-Click toggles the tracker, Right-Click opens settings).
* Hourly instance lockout warning (5/hr) and auto-start on dungeon entry for Dungeon Mode.
* Peer-to-peer version checker to notify in chat when a newer version is out.

### Changed
* Switched Session Gold/Min to Session Gold/Hr.
* Set `hideRaidManager` to off by default for new installs.

### Fixed
* Stopped openable clams from double-counting both the clam and its looted contents.
* Fixed item link parsing on 1.60.1 (`|cnIQ` color codes) so vendor and AH values track properly.

## [0.0.1] - 2026-11-20

### Added
* **Core Addon Framework:** Modular `Init.lua` / `Core.lua` architecture with `SavedVariables` (`CrutchieTweaksDB`), protected module loading (`pcall`), color-coded chat status messages, and `/ct` (`/crutchietweaks`) slash commands.
* **Crutchie's Farm Tracker (`/ct timer`):**
  * Draggable, dark-themed UI with saved screen position and full state persistence across `/reload` and relogs.
  * **Dungeon Mode** vs. **Open World Mode** header toggle (`Dungeon` checkbox).
  * Dual clocks tracking **Session Total** and **Current Run**, with automatic run rollover on instance reset plus a manual **New Run** lap button.
  * Dungeon analytics: **Total Runs**, **Runs / Hour**, **Last Run Clear**, and **Fastest Run**.
  * Gold tracking: **Raw Looted Coin**, **Items (Vendor)**, **Items (AH / Est)** via TSM (`DBMinBuyout` / `DBMarket`) and Auctionator, **Total Session Value**, and **Session Gold / Hr**.
  * Smart item handling: BoP/Soulbound detection (values BoP drops strictly at vendor price), delayed item cache resolution (`GET_ITEM_INFO_RECEIVED`), and openable clam container filtering to prevent double-counting.
  * **Post** channel selector popup (**Say**, **Party**, **Guild**, **Cancel**) to prevent accidental chat posts.
* **HideRaidManager Module:** Permanently hides `CompactRaidFrameManager` when enabled.