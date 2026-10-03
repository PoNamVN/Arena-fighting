# Arena-fighting Design Decisions

Treat these as constraints unless the user explicitly changes them.

## D001 — No Heavy Attack
Knight has no generic Heavy Attack button. Hero identity comes from abilities. Do not add Heavy Attack as a fallback for Counter, Z, X, C, or V.

## D002 — Counter uses LMB
LMB normally starts basic combo. During Counter Window, a new LMB press triggers Knight Counter. Use just_pressed. Held LMB must not repeatedly counter. Counter must not corrupt the basic combo. Counter is not Heavy Attack.

## D003 — Dash costs 0 stamina
Q has cooldown but currently costs zero stamina.

## D004 — Perfect Dodge is timing-based
Perfect Dodge occurs only when the player is inside dodge i-frame, the attack is dodgeable, and the attack would otherwise hit. Do not trigger merely because Q was pressed.

## D005 — Counter is real movement
Counter finds a valid target, lunges toward it, stops near it, and attacks through the existing damage pipeline. No teleport.

## D006 — Ability identity
Z = defense/engage/stagger; X = aerial precision; C = radial melee; V = signature burst/AOE. Do not collapse abilities into generic attack variants.

## D007 — Manual gameplay acceptance
Automated tests establish logic correctness. Manual gameplay establishes feel, visuals, input responsiveness, animation quality, and spatial correctness. Both are required for feature acceptance.

## D008 — One milestone at a time
Do not implement the whole future roadmap in one uncontrolled change. Recommended sequence: Z → X → C → V → complete Knight → future hero architecture.

## D009 — User is final gameplay gatekeeper
Agent implements and reports. User decides ACCEPT/REJECT after manual testing. Agent must not claim user acceptance.
