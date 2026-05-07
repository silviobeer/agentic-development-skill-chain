---
name: requirements-engineer
description: "Erstellt detaillierte Feature Specifications mit User Stories, Acceptance Criteria und Edge Cases nach Visual Companion, Frontend Design und UI Mockup. Verwenden wenn: (1) Concept und ggf. UI-Mockups in strukturierte PRDs verwandelt werden sollen, (2) User Stories und Acceptance Criteria geschrieben werden muessen, (3) Edge Cases identifiziert werden muessen. Nicht fuer: UI-Mockups, Code schreiben, Tech-Design, Debugging."
---

# Requirements Engineer

Verwandle das Concept in strukturierte PRDs (Product Requirements Documents). Fokus auf WAS das Feature tun soll, nicht WIE es implementiert wird.

**Niemals Code oder Tech-Design schreiben** — das machen Solution Architect und Devs.

## PROJ vs. PRD

- **PROJ-X** = die Initiative/das Thema (z.B. `PROJ-1-auth`). Wird im Brainstorming festgelegt und als Folder-Name festgehalten.
- **PRD-Y** = ein einzelnes testbares/deploybares Feature innerhalb des PROJ. Pro PROJ bei 1 starten und hochzaehlen.

## Feature-Granularitaet (Single Responsibility)

**Jede PRD = EINE testbare, deploybare Einheit!**

Faustregel fuer Aufteilung:
1. Kann es unabhaengig getestet werden? → Eigene PRD
2. Kann es unabhaengig deployed werden? → Eigene PRD
3. Hat es eine andere User-Rolle? → Eigene PRD
4. Ist es eine separate UI-Komponente/Screen? → Eigene PRD

Statt EINER grossen PRD → MEHRERE fokussierte Files innerhalb desselben PROJ:
```
specs/PROJ-1-auth/3_PRDs/
  PROJ-1-PRD-1-user-signup.md
  PROJ-1-PRD-2-login.md
  PROJ-1-PRD-3-password-reset.md

specs/PROJ-2-blog/3_PRDs/
  PROJ-2-PRD-1-create-post.md
  PROJ-2-PRD-2-post-list.md
  PROJ-2-PRD-3-post-comments.md
```

Abhaengigkeiten zwischen PRDs (auch ueber PROJ-Grenzen) im File dokumentieren.

## Input

Lese diese Inputs:

1. Concept-Doc: `specs/PROJ-<X>-<thema>/1_brainstorm/PROJ-<X>-concept.md`
2. UI-Mockups: `specs/PROJ-<X>-<thema>/5_mockups/*.html`
3. Sitemap: `specs/PROJ-<X>-<thema>/5_mockups/sitemap.html`
4. UI implementation handoff: `specs/PROJ-<X>-<thema>/5_mockups/implementation-handoff.md`
5. Optional Visual Companion decision: `specs/PROJ-<X>-<thema>/2_visual-companion/layout-decision.md`
6. Optional design language: `specs/PROJ-<X>-<thema>/4_design/design-language.md`

Das Mockup ist bei UI-Features Pflichtinput. Es definiert Screens, Flow, States und wichtige UI-Entscheidungen, aus denen User Stories, Acceptance Criteria und Edge Cases abgeleitet werden. Der `implementation-handoff.md` ist ebenfalls Pflichtinput bei UI-Features; er uebersetzt das Mockup in umsetzbare Vorgaben fuer Komponenten-Reuse, neue Component Candidates, Design Tokens, Interaction Contract und Implementation Tolerance. PROJ-X und `<thema>` wurden im Brainstorming festgelegt und bleiben fuer alle PRDs dieses Projekts gleich.

Wenn ein UI-Feature keine Mockups hat, STOP und zuerst `visual-companion` → optional `frontend-design` → `ui-mockup` ausfuehren. Pure Backend/API-Features duerfen direkt vom Concept kommen.

## Workflow

### 1. Bestehende PRDs pruefen

Vor jeder neuen PRD: Welche PRDs existieren bereits in diesem PROJ? Pruefen via `ls specs/PROJ-<X>-<thema>/3_PRDs/`. Naechste freie `PRD-Y`-Nummer innerhalb des PROJ verwenden (bei 1 starten, keine Luecken). PROJ-X selbst ist bereits vom Brainstorming vergeben.

### 2. Feature verstehen

Bei UI-Features zuerst die Mockups und Sitemap durchgehen:
- Welche Screens existieren?
- Welche User-Flows sind klickbar oder verlinkt?
- Welche States sind sichtbar (Normal, Empty, Loading, Error)?
- Welche Source-Referenzen oder Annahmen sind im Mockup markiert?
- Welcher `Project Mode` gilt (`greenfield`, `brownfield`, `hybrid`)?
- Welche bestehenden Komponenten/Tokens muessen wiederverwendet werden?
- Welche neuen Component Candidates sind vom User akzeptiert?
- Welche Interaktionen sind Implementierungsvertrag und welche Mockup-Elemente sind nur Demo?

Nutze `ask the user directly` mit Multiple-Choice Optionen:
- Wer sind die primaeren User?
- Was ist MVP-Scope vs. Nice-to-Have?
- Welche Constraints existieren?

Eine Frage pro Nachricht. Follow-up Fragen basierend auf Antworten stellen.

### 3. Edge Cases klaeren

Edge Cases mit `ask the user directly` priorisieren lassen:
- Was passiert bei unerwarteten Inputs?
- Wie handhaben wir Fehlerfaelle?
- Security-relevante Szenarien?

### 4. PRD schreiben

PRD in `specs/PROJ-<X>-<thema>/3_PRDs/PROJ-<X>-PRD-<Y>-<kurzbeschreib>.md` speichern. `<kurzbeschreib>` ist kebab-case (z.B. `user-signup`, `post-comments`).

```markdown
# PROJ-<X>-PRD-<Y>: Feature-Name

## Status: Planned

## User Stories

### US-1: Als [User-Typ] moechte ich [Aktion] um [Ziel]
**Given** [Ausgangszustand]
**When** [Aktion]
**Then** [Erwartetes Ergebnis]
**And** [weiteres Ergebnis, falls noetig]

**Acceptance Criteria:**
- [ ] AC-1: Kriterium direkt aus dem Then/And (testbar formuliert)
- [ ] AC-2: Weiteres testbares Kriterium fuer diese Story

### US-2: Als [User-Typ] moechte ich ...
**Given** ...
**When** ...
**Then** ...

**Acceptance Criteria:**
- [ ] AC-3: ...

## Edge Cases
- Was passiert wenn...?

## Abhaengigkeiten
- Benoetigt: PROJ-<X>-PRD-<Y> (falls zutreffend, z.B. PROJ-1-PRD-2)
- Cross-PROJ Abhaengigkeit moeglich (z.B. PROJ-1-PRD-3 braucht PROJ-2-PRD-1)

## Technische Anforderungen (optional)
- Performance, Security, etc.

## UI Implementation Notes (UI PRDs only)
- Project mode:
- Reuse:
- New component candidates:
- Design tokens:
- Interaction contract:
- Implementation tolerance:
```

**Wichtig:** Jede User Story traegt ihre eigenen Acceptance Criteria. Kein separater globaler AC-Abschnitt. Die ACs werden direkt aus den Then/And-Klauseln der Story abgeleitet und testbar formuliert.

### 5. User Review

User um Review bitten via `ask the user directly`. Bei Aenderungswuenschen: Spec anpassen und erneut vorlegen.

### 6. Handoff

Nach Approval → Architecture Skill (3) fuer PROJ-level Tech-Design empfehlen. UI-Mockups sind bereits erledigt und dienen der Architektur als visuelle Referenz.

## Checklist vor Abschluss

- [ ] Bestehende PRDs in `specs/PROJ-<X>-<thema>/3_PRDs/` geprueft (keine Duplikate, naechste freie PRD-Nummer)
- [ ] User hat alle wichtigen Fragen beantwortet
- [ ] Bei UI-Features: Mockups und Sitemap aus `5_mockups/` gelesen und in Stories/ACs beruecksichtigt
- [ ] Bei UI-Features: `5_mockups/implementation-handoff.md` gelesen und UI Implementation Notes in den PRDs beruecksichtigt
- [ ] Mindestens 3-5 User Stories definiert (Given/When/Then)
- [ ] Jede User Story hat eigene Acceptance Criteria (kein globaler AC-Abschnitt)
- [ ] Mindestens 3-5 Edge Cases dokumentiert
- [ ] PRD-ID (PROJ-<X>-PRD-<Y>) vergeben und File im korrekten Ordner gespeichert
- [ ] User hat PRD reviewed und approved

## Git Commit Format

```
feat(PROJ-<X>-PRD-<Y>): Add PRD for [feature name]
```
