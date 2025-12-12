# Mystical Ninja: Recompiled – Mod Builder Helper

Instructions:

    -Launch script by 

    1. Open Powershell as Administrator 
    2. go to where rmt.ps1 is located by typing for example

     cd D:\RMT   then press ENTER

    3.  copy paste this .\rmt.ps1 then press ENTER


This is a little PowerShell helper script I made to make life easier when messing with **Goemon64Recomp** mods.

Instead of:
- typing long paths,
- running `git` / `make` by hand,
- copying builds into the `mods` folder every time,
- and then manually starting the game…

…you just run **one script**, follow a couple prompts, and it does the boring stuff for you.

It also:
- auto-launches `Goemon64Recompiled.exe`
- lets you press **ESC anywhere (even in-game)** to close the game  
  (PowerShell stays open so you can tweak & rebuild fast)

---

## What this script actually does

In plain English:

- ✔️ Checks you have the basic tools:  
  `git`, `make`, and `clang` in your PATH.

- ✔️ Remembers what you used last time:  
  - your **mod folder** (where `mod.toml` + `Makefile` are),
  - your **game’s mods folder**,
  - your **N64Recomp root folder** (where `RecompModTool.exe` lives).  
  Next run it just asks:  
  > Use the same paths as last time? (Y/N)

- ✔️ Uses a folder picker so you don’t have to type long paths  
  You can click to select:
  - your mod folder,
  - your game `mods` folder,
  - and your N64Recomp root if needed.

- ✔️ Double-checks your mod folder  
  It won’t just blindly run:
  - makes sure `mod.toml` exists,
  - makes sure `Makefile` exists,  
  and stops with a clear message if not.

- ✔️ Finds the repo root  
  Walks up from your mod folder until it finds a `.git` folder,  
  so it knows where to run `git submodule update` and look for shared stuff.

- ✔️ Automatically fixes `dummy_headers\stdio.h` (the common size_t issue)  
  If it finds `dummy_headers\stdio.h`, it:
  - creates a backup `stdio.h.bak` (once),
  - if it sees `typedef unsigned long size_t;` it replaces it with  
    `typedef unsigned __int64 size_t;`,
  - if it’s already using `unsigned __int64`, it leaves it alone.

- ✔️ Copies shared `patches` if your mod doesn’t have one  
  If the repo has a top-level `patches` folder and your mod is missing one:
  - it copies it into your mod folder for you.

- ✔️ Keeps track of where `RecompModTool.exe` lives  
  It tries to:
  - reuse whatever worked last time,
  - guess common locations near your repo,
  - and if that fails, lets you pick the folder that contains `RecompModTool.exe`.  
  It saves that for next time too.

- ✔️ Updates and builds  
  - runs  
    ```bash
    git submodule update --init --recursive
    ```  
    in the repo root,
  - runs `make` in your mod folder.

- ✔️ Finds the built files and drops them into the game’s `mods` folder  
  It looks under `build` inside your mod folder for:
  - `.mod`
  - `.nrm`
  - `.bin`  
  and copies them into your selected **mods folder**.

- ✔️ Starts the game for you  
  It assumes:
  - your mods folder is something like  
    `D:\N64\Goemon\mods`
  - so the game is at  
    `D:\N64\Goemon\Goemon64Recompiled.exe`  
  If that exe exists, it starts the game automatically.

- ✔️ Global ESC = kill game (but not the PowerShell window)  
  While the game is running:
  - pressing **ESC** anywhere (even with the game focused) will:
    - close `Goemon64Recompiled.exe`,
    - leave the PowerShell window open  
      → instant rebuild / retry loop.

- ✔️ Colored step-by-step log  
  It prints stuff like:
  - `[1/8] Preparing build environment...`
  - `[8/8] Building mod and installing into game mods folder...`  
  with colors so if something goes wrong, it’s easy to see where.

---

## Requirements

To use this script, you’ll need:

- **Windows 10 or 11**
- **PowerShell 5+** (built-in on Windows) or PowerShell 7
- These tools installed and available in your PATH:
  - `git`
  - `make`
  - `clang`
- A working Goemon64Recomp / N64Recomp setup, with:
  - a mod folder that contains `mod.toml` and `Makefile`,
  - `RecompModTool.exe` somewhere in your N64Recomp / Goemon64Recomp setup.

---