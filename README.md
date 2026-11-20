# CrutchieTweaks

A lightweight, modular quality-of-life and UI utility addon built for **World of Warcraft: Forever** (Interface `16001`).

---

## Features

### 1. Crutchie's Farm Tracker (`/ct timer`)
A movable, persistent gold-per-hour and dungeon run tracker designed for both solo dungeon farming and open-world grinding.
* **Dual-Mode Layout (`Dungeon` Toggle):**
  * **Dungeon Mode:** Tracks your overall **Session Total** alongside your **Current Run** timer, **Total Runs**, **Runs / Hour** (useful for tracking hourly instance reset caps), **Last Run Clear**, and **Fastest Run**. Automatically rolls over to a new run when you reset instances, or manually via the **New Run** button.
  * **Open World Mode:** Collapses into a streamlined single-clock view focused purely on session duration and gold generation.
* **Comprehensive Loot & Gold Valuation:**
  * **Raw Looted Coin:** Tracks exact gold, silver, and copper looted from mobs and chests.
  * **Items (Vendor):** Calculates total vendor sell value of all looted items.
  * **Items (AH / Est):** Automatically pulls live market valuations from **TradeSkillMaster (`TSM_API`)** or **Auctionator** for tradeable items, while accurately valuing Soulbound / Bind-on-Pickup (`BoP`) drops at vendor price and ignoring openable clam shells so contents aren't double-counted.
  * **Session Gold / Hr:** Live gold-per-hour calculation across your entire session.
* **Persistent Across `/reload`:** Active timers, run counts, fastest clear times, and loot totals automatically save across UI reloads and relogs until you click **Reset**.
* **Safe Chat Reporting (`Post`):** Opens a confirmation menu allowing you to post a clean summary to **Say (`/s`)**, **Party (`/p`)**, or **Guild (`/g`)** without accidental chat spam.

### 2. Hide Compact Raid Frame Manager (`hideRaidManager`)
* Permanently hides the default Blizzard Raid/Party side-drawer control panel (`CompactRaidFrameManager`), including across group changes and load-on-demand UI events.
* Can be toggled on or off anytime via slash command.

---

## Slash Commands

| Command | Description |
| :--- | :--- |
| `/ct` or `/crutchietweaks` | Lists all available commands and module toggles. |
| `/ct timer` or `/ct t` | Opens or closes **Crutchie's Farm Tracker**. |
| `/ct hideraidmanager` | Toggles hiding the Blizzard Raid/Party control panel (requires `/reload`). |
| `/ct farmtimer` | Enables or disables the Farm Tracker module (requires `/reload`). |
| `/ct debug` | Toggles verbose loot/coin parsing debug output in chat. |

---

## Installation

1. Download and extract the `CrutchieTweaks` folder.
2. Place it into your World of Warcraft AddOns directory:
   ```text
   World of Warcraft\_forever_\Interface\AddOns\CrutchieTweaks\