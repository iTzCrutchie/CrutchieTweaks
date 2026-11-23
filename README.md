# FarmTracker

A modular gold-per-hour, loot, and dungeon run tracker built for **World of Warcraft: Forever**. It tracks solo dungeon runs and open-world grinding, ranks live gold-per-hour farming spots, logs session history, and lets you customize the UI to fit your setup.

---

## Features

### Farm Tracker (`/ft` or `/ft timer`)
* **Dual-Mode Layout (`Dung` Toggle):** Switch between **Dungeon Mode** (tracks **Session Total** alongside **Current Run**, **Total Runs**, **Runs / Hour**, **Last Run Clear**, **Fastest Run**, and a **5/hr Instance Lockout Warning** with automatic rollover on instance reset or a manual **New Run** button) and **Open World Mode** (streamlined single-clock view focused on session time and gold).
* **Compact Mode & Click-Through:** Collapse the tracker into a single timer and gold-per-hour readout via the header toggle (`-` / `+`), and optionally enable click-through when locked.
* **Loot & Gold Valuation:** Tracks **Raw Looted Coin**, **Items (Vendor)**, **Items (AH / Est)**, **Repair Costs** (including auto-repair addons, while ignoring guild bank repairs), **Net Session Profit**, **Net Gold / Hr**, **Session XP / Hr**, **Time to Level** (hidden at level 60), and **Free Bag Slots**.
* **Valuation Source Toggle:** Switch between **AH + Raw** and **Vendor + Raw** directly from the tracker.
* **Session Gold Goal Bar:** Optional progress bar tracking your net session profit toward a configurable gold target.
* **Auto-Pause & Auto-Resume:** Automatically pauses on AFK or entering cities/rested areas, and resumes when clearing AFK, leaving a rested area, or entering combat (only when auto-paused).
* **Persistence & Reporting:** State persists across `/reload` and relogs until you click **Reset**. Use **Post** to send summaries to **Say**, **Party**, or **Guild**, or open a **Copy (`Ctrl+C`)** window.
* **Window Controls:** Drag to reposition, drag the bottom-right corner to scale the window and font size together, or lock position and sizing from the header or Settings.

### Collapsible Loot Window
* **Side Loot Panel (`>` / `<` Tab):** Displays looted items sorted by value with icons, quality-colored names, stack counts, tooltips, and a quality filter (**All**, **Common+**, **Uncommon+**, **Rare+**, **Epic+**, **Legendary+**).
* **Ignore & Global Blocklist:** Right-click any item in the Loot Window to ignore it for the current session or add it to a global blocklist.
* **High-Value Drop Alerts:** Plays a selectable alert sound (with a mute/flash-only option and test button in Settings) and displays a brief on-screen flash banner when a drop meets or exceeds your threshold.

### Farm Finder (`/ft farms` or Header Map Icon)
* **Live Gold-per-Hour Browser:** Evaluates hourly item yields and raw/vendor gold against your selected AH pricing source and sorts spots dynamically.
* **Built-In Profession Farms (`Data\`):** Includes pre-populated **Mining**, **Herbalism**, **Skinning**, **Cloth**, and **Fishing** entries.
* **Continent, Category & Column Sorting:** Filter by continent (**All Continents**, **Eastern Kingdoms**, **Kalimdor**) and category (**All**, **Custom**, **Mining**, **Herb**, **Skin**, **Cloth**, **Fish**, **Dungeon**, **Grind**), and sort ascending or descending by **Farm / Zone**, **Category**, or **Gold / Hr**.
* **Save from History & `FT1:` Strings:** Click `+` on a saved session in **Session History** to save it as a custom farm with a category and optional `RoutesImportExport` string, or import/share `FT1:...` farm strings with other players.

### Session History (`/ft history` or Header Icon)
* Logs sessions of 10 seconds or longer when you click **Reset** (up to 50 entries).
* Hover any entry for full session details (duration, mode, raw coin, vendor/AH values, repairs, net profit, gold/hr, runs, and XP), click a row to copy its summary, click `+` to save it as a farm, or click `x` to remove individual entries.

### Settings Menu (`/ft config` or Right-Click Minimap Button)
* Organized into four tabs (**Appearance**, **Display**, **Loot & AH**, and **Automation**) and closes with `ESC`.
* Supports **Dark Modern** and **WoW Forever** themes, custom background opacity, font family selection (including `LibSharedMedia-3.0`), font size scaling (`8px–64px`), AH price source selection, drop alert sound/threshold controls, global blocklist management, and stat row toggles.

### Key Bindings & Version Check
* **Key Bindings:** Bind **Toggle Tracker Window**, **Start / Pause Timer**, **Start New Dungeon Run**, and **Toggle Compact Mode** in WoW's Key Bindings menu.
* **Peer-to-Peer Version Check:** Checks versions with guildmates and group members over addon chat channels and notifies you once per session if a newer version is seen.

---

## Slash Commands

| Command | Description |
| :--- | :--- |
| `/ft` or `/farmtracker` | Toggles the Farm Tracker window (or lists commands with `/ft help`). |
| `/ft timer` or `/ft t` | Opens or closes the Farm Tracker window. |
| `/ft farms` or `/ft finder` | Opens or closes the Farm Finder window. |
| `/ft history` or `/ft hist` | Opens or closes the Session History log. |
| `/ft config` or `/ft menu` | Opens or closes the Settings menu. |
| `/ft testalert` | Previews the High-Value Drop Alert. |
| `/ft debug` | Toggles loot and coin debug output in chat. |

---

## Installation

1. Download and extract the `FarmTracker` folder.
2. Place it into your World of Warcraft AddOns directory:
   ```text
   World of Warcraft\_forever_\Interface\AddOns\FarmTracker\