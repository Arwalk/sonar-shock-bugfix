SONAR SHOCK — COMMUNITY BUGFIX PATCH v1.0
==========================================
An unofficial fan patch for Sonar Shock (Steam, Godot 4.2.2 build).
It becomes obsolete the moment the developer ships these fixes officially —
the same fixes have been sent upstream as SonarShock_bugfixes.patch.

WHAT IT FIXES
-------------
 * Getting PERMANENTLY STUCK under shelves/tables/ducts after crouching.
   (The stand-up check was a single thin ray that missed object edges, and
   the collider grew back into geometry, wedging the player. It is now a
   proper full-body check, plus the game auto-ducks you free if you ever do
   get wedged — including in old "stuck" save files.)
 * The framerate collapsing after a few hours of play ("memory leak").
   (Bullet holes, casings and blood never got deleted and piled up forever.
   They are now capped: the newest ~700 effects stay, the oldest recycle.)
 * A 1-in-6 chance of the elevator SOFT-LOCKING during low-sanity rides.
 * A couple of small script bugs.
No exe, DLL, or save files are modified, and existing saves stay compatible.

REQUIREMENTS
------------
 * Windows 10/11 (uses the built-in PowerShell — nothing to install).
 * The current Steam build of Sonar Shock. The patcher fingerprints your
   game file first and simply REFUSES to run on any other version, so it
   cannot damage an unknown installation.
 * About 1.8 GB of free disk space (for the safety backup).

HOW TO APPLY
------------
 1. Copy ALL files from this folder into your Sonar Shock game folder
    (the one containing "Sonar Shock.exe"). Right-click the game in Steam
    -> Manage -> Browse local files, if you're not sure where that is.
 2. Make sure the game is closed.
 3. Double-click  ApplyPatch.bat  and wait for "SUCCESS".
That's it — start the game normally.

HOW TO UNDO
-----------
Double-click  RestoreOriginal.bat  — it copies the automatic backup
("Sonar Shock.pck.orig") back into place. Alternatively, "Verify integrity
of game files" in Steam restores the original too.

SAFETY, FOR THE CAUTIOUS
------------------------
 * ApplyPatch.ps1 is plain text — open it in Notepad and read exactly what
   it does before running it.
 * It verifies the SHA-256 of your game file BEFORE touching anything,
   rebuilds the 12 patched scripts in memory and checks each against a
   known-good fingerprint, makes a full backup, and after writing verifies
   the finished file end-to-end. If ANY check fails, it restores the backup
   and leaves your game exactly as it was.
 * Fingerprints (SHA-256):
     original  Sonar Shock.pck : 98332c90d863c6ecf975cc29342608ef2a8732787de9f10fbc459cdd1ead7e01
     patched   Sonar Shock.pck : 9f03f18b2aae68e873c8b0d77778834b6c6dd7088f315961126270d81fd7c11e
 * SonarShock_bugfixes.patch is the complete, human-readable list of code
   changes (the same document sent to the developer). PATCH_NOTES.txt has a
   plain-language summary.

FILES IN THIS PACKAGE
---------------------
  ApplyPatch.bat            — double-click this to patch
  ApplyPatch.ps1            — the patcher itself (readable source)
  RestoreOriginal.bat       — double-click to undo
  SonarShock_bugfixes.patch — the exact code changes, with explanations
  PATCH_NOTES.txt           — plain-language summary of the fixes
  README.txt                — this file

This is an unofficial community patch, not affiliated with the developer.
It ships no game content — it only modifies the copy of the game you own.
