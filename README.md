# Character DNA 0.3.0

Capture numerical appearance profiles, keep named presets, export/import them,
and restore their body and appearance choices as a barber-shop preview. You
click WoW's Accept yourself to finalize and pay. Tested locally on Forever beta
1.60.1 build 70450/interface 16001; release-client support is not yet verified.

## Install from GitHub

Download the repository ZIP, extract it, and rename its addon folder to
**CharacterDNA**. Place it in the intended client's `Interface/AddOns` directory,
with `CharacterDNA.toc` directly inside that folder. Restart WoW and enable it.
Source downloads do not include your saved profiles. Export/import profiles or
back up the client's account-level `SavedVariables/CharacterDNA.lua` separately.
Capture/apply currently refuse unverified client builds; importing preserves
profile data but does not override compatibility checks.

## Quick start

Installed in the Forever beta client's `Interface/AddOns/CharacterDNA` folder.
Restart the client if the new addon is not listed, enable Character DNA, then
log in. Click the round book icon on the minimap's lower-left rim to
open/close the panel; right-click it for diagnostics. A chat hint also appears
on login. `/cdna` opens the movable panel; Escape closes it. `/cdna scan` shows
copyable runtime diagnostics; `/cdna export` exports the selected profile.
With no profile selected, export shows the last scan instead.

Entering a barber shop automatically queues a background scan after a short
delay for the UI data to load. Observed customization-change events queue another
scan, with repeated events combined. While the barber is open, a read-only timer
refreshes the scan/capture once per second even when choice-change events are
absent. The timer stops on close. The latest barber scan stays available via
**Last scan** after you leave, and persists in SavedVariables on normal reload or
logout. Scanning outside a barber shop does not overwrite that saved barber scan.
No panel opens automatically. A **Character DNA / Scan** button above the choices panel
inside the barber shop can open the diagnostics there. This button and the panel
use an independent overlay while the barber shop hides the normal WoW interface.

Background scanning, loading, and import never change appearance. Preview changes
require explicit Apply profile / Confirm preview clicks. The adapter is limited to Forever
1.60.1 build 70450/interface 16001 and the observed category/options structure.
For each option it validates `option.id`, a positive Lua `currentChoiceIndex`,
and numeric `choices[currentChoiceIndex].id`. It stores IDs separately from the
index. Missing/invalid records remain unavailable and appear in capture status.
Selected choice records now appear in diagnostics for in-game confirmation.
Other builds fail closed. See DISCOVERY.md for evidence and remaining checks.

Background capture retains the latest snapshot without creating named profiles.
After leaving, Save capture uses that snapshot only for the same character,
race/class and build; otherwise it saves metadata with unavailable appearance.
The snapshot can include uncommitted/cancelled preview selections. Body type is
read from the barber's GetCurrentCharacterData and mapped through Enum.UnitSex
to the profile's existing UnitSex codes (2 male / 3 female). Other identity remains
from Unit APIs. Unknown preview bodies remain unavailable. Older captures made
while previewing a body different from the logged-in character may have the wrong
body recorded; recapture those profiles. Existing correctly identified profiles
remain compatible without conversion.

## Profiles

Enter a unique name and click Save capture. Click the **Saved profile** picker
to see saved names; click a name to load that record into the panel. The list
has page buttons for more than six profiles. **Load profile** redisplays the
selected record. The last selected profile is remembered across `/reload` and
logout/login, and opens automatically with the panel. If it was removed, the
first remaining profile is selected. Previous/Next also loads saved profiles;
Inspect displays identity and all recorded option/choice pairs. Loading only
displays the stored record. Select a saved
profile and click Save capture with its existing name to explicitly update it
with the latest capture. Rename uses the
name field; existing names are never overwritten. To delete, the name field must
exactly match the selected profile. SavedVariables persist on normal logout or
`/reload`. A crash before the client writes SavedVariables may lose changes.

Manual help clears the editor for known numeric IDs. Enter one pair per line:
`optionID choiceID optional label`, then Save manual. These are user-supplied IDs,
not a mapping from UI numbers. Manual entries preserve IDs without verifying
their race, build, or availability. No import or selection applies anything.

Export selects portable text; Ctrl+A/Ctrl+C copies it. Paste CDNA1 text into the
editor and click Import text. Duplicate profile names are rejected: rename or
delete the existing profile first. Import validates schema, records, integer
ranges, duplicate option IDs, maximum 256 options, and maximum 65536 bytes.
It never evaluates Lua. Unknown numeric IDs are preserved. Names/labels support
UTF-8 through percent escaping; indexes are optional diagnostics with no assumed
base. CDNA1 is a version-1 tab-separated format, not JSON. All metadata records
are required, and output sorts appearance pairs by option ID.

## Apply a saved profile

1. Enter the barber shop and open Character DNA using its button above the choices.
2. Choose a saved profile from the picker.
3. Click **Apply profile**. Review the current-to-saved choice ID differences.
4. Click **Confirm preview**. The addon sets the choices and checks the results,
   then hides its panel so you can inspect your character and the barber controls.
   If the saved body differs, the first confirmation restores that body only.
   After its options load, the addon shows a fresh appearance diff; click
   **Confirm preview** again to restore those choices. If the options are still
   loading, wait and click Apply profile again. The delayed review never sets
   choices without your second click.
5. Click WoW's **Accept** yourself to finalize and pay, or WoW's **Cancel** to discard.

The addon never calls `ApplyCustomizationChoices`, Accept, Cancel, or a reset.
Choice confirmation calls `SetCustomizationChoice(optionID, choiceID)`.
Body confirmation uses the existing barber UI's `SetCharacterSex`, which calls
`SetSelectedSex` with the client enum and updates its body controls. Both require
a user click. The normal barber body-change path may reposition its camera.
No profile is applied on load, selection, login, import, or background scans.

Apply requires the same saved/runtime client build and race. It verifies the
preview race against UnitRace and the preview body through Enum.UnitSex. A
different body produces a body-only review before any appearance IDs are used.
Once the body matches, every saved choice must exist and be explicitly unlocked
and eligible. Altered forms/custom models and automatic HD/SD changes remain
unsupported. Unavailable choices block appearance application; the body preview
may already have changed in the prior stage. A changed profile or barber selection
invalidates the review and requires reviewing again.

The client can change dependent choices when a setter runs. The addon rereads
eligibility between calls and verifies all saved choices afterward. If any setter
is rejected/protected, or a dependency prevents a complete match, it stops and
reports the failure. Earlier preview changes may remain; review them or use WoW's
Cancel. There is no retry through protected UI, automatic rollback, or payment.

## In-game acceptance checklist (requires user execution)

1. Enable Lua error display if desired (`/console scriptErrors 1`). Login and
   run `/cdna scan`. Confirm build/interface and no Lua errors.
2. Open a barber, wait a moment, and confirm the background scan notification.
   Leave, open DNA and click Last scan; copy diagnostics with Ctrl+A/Ctrl+C.
   Reopen the barber and verify the Character DNA / Scan button above the choices opens
   a visible, clickable panel even while the minimap/chat are hidden. Change one
   choice, scan, cancel, reopen, and scan again. Record which events appeared.
   Save capture and Inspect should show numeric option/choice IDs and diagnostic
   indexes, rather than metadata only. Confirm selected choice names/IDs against
   a changed option and the selected-record diagnostics. The addon never commits
   changes or spends currency.
3. Save two differently named metadata captures. Browse, inspect, rename,
   export, delete one, then paste and import its export. Compare identity/IDs.
4. Try manual pairs with Unicode labels, optional empty labels, and zero IDs.
   Export and reimport under a different profile name; compare numeric pairs.
5. Reject duplicate option IDs, corrupt percent escapes, missing records,
   CDNA2, negative/oversized IDs, and inputs exceeding the limits. Errors appear
   in chat and should leave profiles unchanged.
6. `/reload`, then logout/login. Confirm both profiles and names persist.
7. Repeat with different race/body types and barber options having zero or
   multiple choices. Unknown/missing information must remain unavailable.
8. Watch for Lua errors/taint during normal play and barber cancel/reopen.
9. Save a profile, manually change several barber choices, then use Apply profile.
   Check the diff; confirm the preview; verify all controls return to saved values
   and WoW's Accept becomes available when changes exist. Cancel once to verify
   no changes are purchased automatically. Then repeat and click Accept yourself.
10. Confirm applying outside the barber, to a different race, or with unknown
    or locked choice IDs is refused. Changing a choice after reviewing the diff
    must invalidate the confirmation. Merely loading a profile must change nothing.
11. Starting with a female profile, preview male with different hair/skin. Apply
    the female profile: confirm body first, then confirm the appearance diff.
    Verify the body, hair, skin and other choices match before accepting. Repeat
    the reverse direction with a freshly captured male profile. Cancel a body
    review and close/reopen the barber to verify no delayed application occurs.

For an issue, include addon version, full copied scan, exact reproduction steps,
whether the barber was open, and any Lua error. Diagnostics include build and
raw appearance records; review copied text before sharing. Profiles also include
character name. Never include account credentials or complete WTF files.

## Validation limits

Offline tests cover serialization, storage, manual entry, bounded diagnostics,
and mocked UI/event loading. Preview tests cover nine-choice setting, compatibility,
eligibility, stale confirmation, rejection, partial/dependency failures and zero
commit calls. Actual client load, frame compatibility, event
delivery, SavedVariables persistence, and absence of taint need in-game testing.
No creator-screen capture is supported. Preview application still requires live
beta validation; errors stop without bypassing client restrictions.
