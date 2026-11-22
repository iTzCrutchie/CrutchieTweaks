---

### `CHANGELOG.md`

```markdown
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
* Clamped text inside the Font Family and AH Price Source buttons so long names no longer overflow the button borders.v

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