# Local discovery — 2026-10-20

User confirmed `_classic_beta_` is their WoW Forever beta client.
Root: `C:\Program Files (x86)\World of Warcraft\_classic_beta_`.
The installation `.build.info` lists `wow_classic_beta`, version `1.60.1.70450`.
`.flavor.info` identifies `wow_classic_beta`. Installed Decursive and Forever
addons declare interface `16001`; this is the manifest evidence used for the TOC.
The runtime scan must confirm the actual running build/interface.

No loose `Interface/FrameXML`, Blizzard UI addons, or shipped API documentation
were found in this client's Interface directory. Searching its Lua/XML files for
the customization namespaces and barber events returned no matches. No archive,
binary, process memory, or network inspection was performed.

## Capabilities and blockers

Initial discovery had no verified barber signatures or return shapes.
The addon reports types of namespace members, including
`C_BarberShop.GetAvailableCustomizations`, `GetCustomizationChoices`, and
`SetCustomizationChoice`. It never invokes a setter. Only
`GetAvailableCustomizations()` is sampled, under `pcall`, after a barber-open
event. The sample is bounded and reports raw field names/values for review.
`GetCustomizationChoices` is not called because its signature is unknown.
`C_CharacterCustomization` is enumerated without invoking its functions.

The initial release disabled automatic extraction. See the 0.1.3 runtime evidence
below for the now-enabled, build-limited reader. Manual IDs remain explicitly
marked user-supplied and unverified.

Identity uses guarded UnitRace/UnitSex/UnitClass/UnitName calls; IDs are stored
only when returned, separately from appearance. Sex is the raw UnitSex value.
UTC timestamp uses `date` with a UTC format when available, with local fallback.
Observed event names are retained in a bounded session log. Registration of
candidate barber events is guarded because event availability is unknown.

Server-specific policy has not been verified. There is no restore code or
protected action automation. Restore requires separate policy and API review.

## Next evidence needed

Copy `/cdna scan` before entering a barber, while open, after changing a choice
without committing, and after cancel/reopen. Confirm the runtime interface/build
and paste the raw option/choice records. Only then implement a narrow reader
for the demonstrated shape and verify IDs against multiple selections/races.

## User testing follow-up

The user confirmed the barber shop replaces/hides the normal WoW GUI; the initial
UIParent-child launcher and panel were inaccessible there. Version 0.1.2 detects
BARBER_SHOP_OPEN and queues a background scan, retaining the latest barber result
separately from later world scans. Last scan retrieves it after leaving. A detached
overlay hosts a barber button and the panel during the barber session, without
showing or modifying WoW's hidden UIParent. BARBER_SHOP_CLOSE restores the panel's
ordinary parent. Visibility, event queueing/cancellation and result retention have
offline regression coverage; actual event delivery and overlay interaction still
need in-game confirmation.

## 0.1.3 — runtime category/option evidence

User supplied a successful in-game scan on 1.60.1/70450/interface 16001 with
BARBER_SHOP_OPEN observed. `C_BarberShop.GetAvailableCustomizations` is callable;
`GetCustomizationChoices` and `C_CharacterCustomization` are absent.
The return is a Lua array of categories, each containing `options`. Options have
numeric `id`, labels, `currentChoiceIndex`, and a `choices` array. Observed IDs:
14 Skin Color, 15 Face, 16 Hair Style, 17 Hair Color, 464 Eye Color, 970 Eyebrows,
526 Face Shape, 501 Piercings, 516 Makeup. These are observations for this
character, not a universal mapping. Never hardcode them into capture logic.

The prior diagnostic depth replaced each choice record with `<table>`; it did
not prove absence of choice IDs. The updated scan prints each selected record
separately, and samples the read-only GetCurrentCharacterData getter if present.
Its return is diagnostic only, pending shape verification.

Blizzard's shared UI schema identifies `currentChoiceIndex` as a Lua index and
the nested choice's `id` as its numeric identifier:
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CharacterCustomizationSharedDocumentation.lua
This shared source is supporting schema evidence, not proof of Forever behavior.
The adapter additionally requires the exact tested client build, validates the
actual runtime selected record and numeric IDs, refuses zero-based tables and
missing indexes, and rejects duplicate option IDs. No index offsets are guessed.
In-game confirmation of the selected choice records/labels is still required.

Background scans now retain the latest full snapshot as `lastCapture`, separate
from named profiles; Save capture copies it during/after the barber session.
Polling once per second covers absent change events and is cancelled on close.
Identity remains Unit API data, so preview body/form compatibility is unverified.
Snapshots may contain uncommitted/cancelled selections. No restore is implemented.

## 0.1.4 — confirmed capture and saved-profile selection

User supplied a saved 0.1.3 capture with nine numeric option/choice pairs, including
Skin Color 14/86 at index 2 and Hair Style 16/152 at index 21. This confirms the
reader is returning separate real choice IDs on this character/build. Other
races/body types and cross-build compatibility still need in-game coverage.
The panel now includes a named profile picker, Load profile, and persisted last
selection. Loading displays the saved record; it does not apply choices. Restore
remains a separate milestone requiring compatibility checks and policy review.

## 0.2.0 — explicit barber preview application

The user authorized adding Apply profile after successful capture tests. Restore.lua
is a separate module; all background capture/import/profile selection paths remain
read-only. A review of differences precedes a separate Confirm preview click.

Source evidence was found in the `forever` UI-source branch, specifically
BarberShopMixin:SetCustomizationChoice calling the API with optionID, choiceID,
then updating the UI; ApplyChanges separately calls ApplyCustomizationChoices:
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_BarbershopUI/Mainline/Blizzard_BarberShopUI.lua
The generated API declaration agrees on the setter's arguments:
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/BarberShopDocumentation.lua
This is mirrored Blizzard UI source, not proof of successful calls in this running
beta. Runtime testing of setter access remains required; any rejection stops the
operation, with no secure-call workaround or protected button automation.

The local installation is the Blizzard client. Reviewed Blizzard's published UI
Add-On Development Policy (including visible code, no negative realm/player impact,
and respecting disabled functionality):
https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642
No special server policy granting broader permissions is assumed. This addon only
uses the exposed choice setter after a user click and does not finalize purchases.

The user's diagnostic confirms GetCurrentCharacterData returns Human/fileName,
sex=1 for the character whose UnitSex value is 3. The Forever UI uses Enum.UnitSex
for that data. Apply compares the actual client enums, not hardcoded enum offsets,
and checks the selected preview race/body against the logged-in character. It
requires matching profile race/body/build and current unlocked/eligible choice IDs.
Altered forms and custom model views are blocked. Missing choices block preflight.

Confirm revalidates the review against live data. Each setter is guarded; choices
are reread between calls and the complete profile is verified after setting.
Dependencies/rejections can leave partial previews, reported explicitly; no
automatic rollback or commit occurs. Normal WoW Cancel remains the recovery path.
Offline tests prove nine-choice setting with zero commit calls and rejection of
incompatible, stale, missing, locked, protected, no-op and dependent failures.

## 0.3.0 — profile body restoration

User testing confirmed preview application worked, but a male barber preview
blocked a female profile until the body was manually switched back. The 0.2.x
body-equality guard caused that limitation; it was not a missing UI button.

The same Forever UI source has SetCharacterSex calling SetSelectedSex(enum),
registering the camera update event and refreshing the body controls. A separate
confirmed body stage now uses this normal UI method. After a short delay, the
addon only rereads and displays the new body's appearance diff. A second user
click is required before any appearance setter runs; neither stage commits.
Race/build/form restrictions, stale-review checks and eligibility checks remain.

Capture now reads the actual preview body via GetCurrentCharacterData and the
client's enums. The stored sexID keeps its existing UnitSex-style representation,
so no schema change or silent conversion of older records is needed. Unknown
preview identity is unavailable. Older incorrectly identified previews require
recapture; the stored appearance IDs alone are not used to guess a body.

Regression tests cover male-to-female and female-to-male restoration, distinct
body-specific choice IDs, two separate confirmations, preview-body capture and
export, reuse after leaving, stale/rejected body calls and cancelled delayed
reviews. No commit calls occur. Actual beta body-switch testing remains required.
