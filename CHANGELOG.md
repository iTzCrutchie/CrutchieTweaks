---

### `CHANGELOG.md`

```markdown
# Changelog

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