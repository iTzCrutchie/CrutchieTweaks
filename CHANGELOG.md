---

### `CHANGELOG.md`

```markdown
# Changelog

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