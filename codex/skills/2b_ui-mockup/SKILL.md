---
name: ui-mockup
description: "Erstellt leichtgewichtige HTML-Mockups und eine visuelle Sitemap vor dem Requirements Engineer. Input ist das ausgewaehlte Wireframe/Layout aus visual-companion plus optional frontend-design. Verwenden wenn: (1) UI-Flows vor Requirements und Architektur visualisiert werden sollen, (2) eine Sitemap der Seitenstruktur benoetigt wird, (3) Stakeholder visuelles Feedback geben sollen bevor User Stories festgeschrieben werden. Nicht fuer: Requirements, Komponenten-Bibliotheken, technische Architektur."
---

# UI Mockup & Sitemap Generator

Erstelle leichtgewichtige HTML-Mockups und eine visuelle Sitemap basierend auf Concept + Visual-Companion-Entscheidung. Rein visuell — keine technischen Entscheidungen und keine Acceptance Criteria.

**Bei UI-Features ist dieser Skill vor Requirements erforderlich.** Pure Backend/API-Features ueberspringen ihn.

Zusätzlich erzeugt der Skill einen kompakten **Implementation Handoff**. Dieser macht die visuelle Entscheidung fuer Requirements, Architecture, Writing Plans und Execution umsetzbar, ohne dass Implementierer das HTML-Mockup interpretieren muessen.

## Prinzipien

- **Leichtgewichtig:** Einzelne HTML-Dateien, nur Inline-CSS und kleines Vanilla-JS, keine externen Abhaengigkeiten
- **DRY im Mockup:** Wiederverwendbare CSS-Klassen, HTML-Patterns und kleine JS-Helper nutzen statt pro Screen/Element neuen Code zu schreiben
- **Interaktiv:** Klickbare Flows, Tabs, Sidepanels, Modals, Drawers, Wizard-Steps und State-Wechsel duerfen/sollen gezeigt werden, wenn sie fuer das UI-Verstaendnis helfen
- **Einfach:** Kein Over-Engineering, keine JavaScript-Frameworks, keine komplexen Animationen
- **Design-Erkennung:** Wenn ein bestehendes UI existiert, Farben/Fonts/Spacing uebernehmen (Tailwind Config, CSS Variablen, Design Tokens scannen)
- **Component-Reuse:** Bestehende Komponenten und Patterns zuerst nutzen, neue UI-Bausteine nur als Kandidaten markieren
- **Komponentennaehe statt Pixelperfektion:** Bestehende React-Komponenten visuell und strukturell annaehern. Das Mockup muss nicht 1:1 pixelgenau sein, aber die beabsichtigte Wiederverwendung muss erkennbar und gelabelt sein.
- **Alle States zeigen:** Empty, Loading, Error, Success als sichtbare Sektionen pro Seite

## Input

Lese diese Inputs:

1. Concept: `specs/PROJ-<X>-<thema>/1_brainstorm/PROJ-<X>-concept.md`
2. Visual Companion: `specs/PROJ-<X>-<thema>/2_visual-companion/layout-decision.md`
3. Visual Companion prototype: `specs/PROJ-<X>-<thema>/2_visual-companion/layout-exploration.html`
4. Optional design language: `specs/PROJ-<X>-<thema>/4_design/design-language.md`

Die ausgewaehlte Richtung in `layout-decision.md` ist verbindlich. UI-Mockup verfeinert diese Richtung in konkrete Screens und States. Es erfindet keine alternativen Layout-Container mehr, ausser der User fordert das explizit.

Lies aus `layout-decision.md` besonders:
- `Project Mode` (`greenfield`, `brownfield`, `hybrid`)
- `Selected Direction`
- `Shape Brief`
- `Existing UI Patterns`
- `Design/component gaps`

## Workflow

### 1. Design System, Komponenten und App-Shell erkennen

**Design System Referenz laden:**
Wenn `4_design/design-language.md` existiert, ist es die primaere Design-Referenz.
Suche nach `.codex/skills/references/design-system.md` (erst im Projekt, dann global unter `~/.codex/skills/references/`). Falls vorhanden: Farben, Typografie, Spacing, Komponenten-Muster und Do/Don't-Regeln daraus uebernehmen.

**Falls keine Referenz existiert**, scanne das Projekt nach:
- `tailwind.config.*` → Farben, Fonts, Spacing
- CSS Custom Properties (`--color-*`, `--font-*`)
- `globals.css` oder `theme.css` → Design Tokens
- Bestehende HTML/CSS Dateien fuer visuellen Stil

Falls gefunden: Stil in Mockups uebernehmen.
Falls nicht: Minimales, sauberes Default-Styling (System-Fonts, neutrale Farben).

**Bestehende Komponenten erkennen:**
Scanne vor dem Mockup-Bau:
- `docs/components.md` — primaere Component Registry, falls vorhanden
- `src/components/**`
- `src/features/*/components/**`
- UI-Library-Hinweise in `package.json` (z.B. shadcn/radix/mui/chakra/headless)
- bestehende Dialog/Modal/Drawer/Table/Form/Button/Card/Badge/Tabs/Command-Komponenten

Erstelle intern eine kurze Component Map:
```markdown
Reuse candidates:
- Button: `src/components/ui/button.tsx`
- Dialog: `src/components/ui/dialog.tsx`
- DataTable: `src/components/data-table.tsx`

New component candidates:
- BulkActionBar — no matching batch-action component found
```

Mockups muessen vorhandene Komponenten als Bausteine benennen und grob in deren Struktur/Stil annaehern. Beispiel-Labels:
- `[Reuse: Button] Save`
- `[Reuse: Dialog] Confirm delete`
- `[Reuse: DataTable] Orders`
- `[New candidate: BulkActionBar]`

Neue UI-Elemente nicht stillschweigend erfinden. Wenn kein passender bestehender Baustein existiert, als `New candidate:` markieren und im Mockup kurz begruenden.

Pixelperfektion ist nicht Ziel dieses Skills. Wenn ein HTML-Mockup eine React-Komponente nur ungefaehr trifft, ist das akzeptabel, solange spaeter klar ist, welche echte Komponente verwendet werden soll.

**App-Shell erkennen:**
Suche nach dem aeussersten Layout (`src/app/**/layout.tsx` oder aehnlich) und identifiziere:
- **Header/Topbar:** Position, Hoehe, Hintergrundfarbe, Breadcrumb-Struktur
- **Sidebar:** Breite, Farbe, Navigationspunkte, aktiver Zustand
- **Main Content Area:** Padding, Scrollverhalten, max-width

Falls ein App-Shell existiert: Jedes Mockup zeigt den Content **eingebettet im App-Shell** — nicht isoliert. Der Shell wird als statische Huelse mit Platzhalter-Navigation dargestellt.

Falls kein App-Shell existiert (z.B. Landing Page, Login): Mockup ohne Shell erstellen.

### 2. Sitemap erstellen

Erstelle `specs/PROJ-<X>-<thema>/5_mockups/sitemap.html` — eine visuelle Uebersicht:

```
Inhalt der Sitemap:
- Alle Seiten/Screens als Boxen
- Hierarchie (Parent → Child Beziehungen)
- Navigation-Flows (Pfeile zwischen Seiten)
- User-Flows farblich markiert (z.B. "Login Flow", "Checkout Flow")
- Rollen-Zuordnung (welche Seiten fuer welche User-Rolle)
```

Umgesetzt als reine HTML/CSS Boxen mit Verbindungslinien (CSS borders/pseudo-elements, kein JS, kein SVG noetig).

Jede Box in der Sitemap verlinkt auf das entsprechende Mockup-File.

### 3. Seiten-Mockups erstellen

Pro Screen eine Datei in `specs/PROJ-<X>-<thema>/5_mockups/`:
```
specs/PROJ-1-auth/5_mockups/
  sitemap.html
  PROJ-1-PRD-1-login.html
  PROJ-1-PRD-2-signup.html
  PROJ-1-PRD-3-password-reset.html
  ...
```

Jedes Mockup enthaelt:
- **App-Shell** (falls erkannt): Statische Huelse mit Header, Sidebar und Content-Area. Der Feature-Inhalt wird in der Content-Area platziert. Die Shell zeigt:
  - Header mit Platzhalter-Breadcrumb und Avatar
  - Sidebar mit Navigationspunkten (aktiver Punkt hervorgehoben fuer den aktuellen Screen)
  - Main-Area mit korrektem Padding/Spacing
- **Mockup-Header:** Seitenname + PROJ-Referenz + Link zurueck zur Sitemap (als kleines Banner oberhalb des App-Shells)
- **Navigation:** Links zu verbundenen Mockup-Seiten (klickbarer Flow)
- **Hauptinhalt:** Layout mit Platzhaltern fuer Texte, Bilder, Formulare — innerhalb der Content-Area
- **Komponenten-Hinweise:** jedes wichtige UI-Element ist mit `Reuse: <Component>` oder `New candidate: <Component>` markiert
- **Interaktion:** relevante Klickpfade funktionieren mit kleinem Inline-JS, z.B. Modal oeffnen/schliessen, Sidepanel toggeln, Wizard weiter/zurueck, Tab wechseln, Filterzustand simulieren
- **State-Varianten:** Sektionen fuer verschiedene Zustaende, jeweils mit Ueberschrift:
  - `[Normal State]` — Standardansicht mit Beispieldaten
  - `[Empty State]` — Keine Daten vorhanden
  - `[Loading State]` — Ladezustand
  - `[Error State]` — Fehlerzustand
- **Source-Referenz:** Kleine Labels welche Concept-Section, Visual-Companion-Entscheidung oder Mockup-Annahme ein UI-Element abdeckt. Keine Acceptance-Criteria-Labels, weil Requirements erst danach geschrieben werden.

**Tipp:** Den App-Shell als wiederverwendbares HTML-Fragment in `specs/PROJ-<X>-<thema>/5_mockups/_shell.html` extrahieren und per `<iframe>` oder Copy-Paste in allen Mockups nutzen — oder als CSS/HTML-Block am Anfang jeder Datei.

**Interaktions-Regeln:**
- Nutze nur Vanilla-JS innerhalb der HTML-Datei.
- Interaktion demonstriert Verhalten, nicht finale Implementierung.
- Buttons/Links sollen im Mockup sichtbar reagieren, wenn dadurch der Flow klarer wird.
- Keine Persistenz, keine API-Calls, kein Build-Step.
- Wenn mehrere Screens zusammen einen Flow bilden, verlinke sie; wenn ein Overlay/Panel zur ausgewaehlten Visual-Companion-Richtung gehoert, simuliere es im selben Mockup.

**Code-Minimalismus fuer HTML-Mockups:**
- Erstelle wenige generische CSS-Primitives (`.shell`, `.panel`, `.toolbar`, `.button`, `.table`, `.state`, `.overlay`) und verwende sie ueberall wieder.
- Nutze `data-*` Attribute fuer Interaktion, z.B. `data-open="trend-panel"` statt pro Button eigene JS-Funktion.
- Nutze einen kleinen zentralen JS-Handler fuer wiederkehrende Aktionen: open/close overlay, switch tab, next/prev step, select row.
- Vermeide duplizierte Markup-Bloecke. Wenn mehrere Screens gleich aufgebaut sind, nutze dieselbe Struktur mit anderen Labels/Placeholdern.
- Keine grossen Beispiel-Datensaetze. 2-3 Rows/Cards reichen, um Struktur und State zu zeigen.
- Keine langen CSS-Resets oder Utility-Klassenlisten. Nur die Klassen definieren, die im Mockup tatsaechlich genutzt werden.
- Keine detaillierte Kopie echter Komponenten. Eine komponentennahe Approximation + `Reuse:` Label reicht.

Guter Prompt an dich selbst vor dem Schreiben:

> "Can I express this mockup with fewer reusable primitives? Which CSS class, HTML block, or JS handler can serve multiple screens/interactions?"

Wenn du merkst, dass ein Mockup viel Code braucht, reduziere zuerst die Detailtiefe statt neue Abstraktionen aufzubauen. Ziel ist klares Entscheiden, nicht vollstaendige UI-Simulation.

### 4. User Review

Mockups im Browser oeffnen lassen. Feedback via `ask the user directly`:
- Stimmt die Seitenstruktur?
- Fehlen Screens oder Flows?
- Passen die States?

Bei Aenderungen: Mockups anpassen und erneut vorlegen.

### 5. Implementation Handoff

Erstelle nach den Mockups:

```text
specs/PROJ-<X>-<thema>/5_mockups/implementation-handoff.md
```

Dieser Handoff ist Pflicht bei UI-Features und wird von Requirements, Architecture, Writing Plans und Execution gelesen.

Struktur:

```markdown
# PROJ-<X> UI Implementation Handoff — <thema>

## Project Mode
greenfield | brownfield | hybrid

## Source References
- Concept:
- Visual Companion decision:
- Mockups:
- Design language:

## Selected UI Direction
[One paragraph: selected container/model, e.g. radar-first with overlapping sidepanels.]

## Reuse
- Component: `path/to/component.tsx` — intended use

## New Component Candidates
- ComponentName — why no existing component fits

## Design Tokens And Styling
- Use:
- Avoid:
- Existing app design takes precedence over exact HTML mockup CSS: yes

## Interaction Contract
- Interaction:
- Required states:
- Responsive/mobile behavior:

## Implementation Tolerance
- Mockups are structural, not pixel-perfect.
- Existing React components and design tokens take precedence over mockup CSS.
- Preserve the selected layout direction and interaction contract unless the user approves a change.

## Demo-Only In Mockup
- [Things shown only to explain the flow and not required for implementation.]

## Open UI Risks
- [Ambiguities or component gaps Architecture/Writing Plans should account for.]
```

Der Handoff muss explizit genug sein, dass ein Implementierer weiss:
- welche bestehenden Komponenten wiederzuverwenden sind
- welche neuen Komponenten gebaut werden duerfen
- welche Tokens/Schriften/Farben verbindlich sind
- welche Interaktionen wirklich implementiert werden muessen
- wo HTML-Mockup-Abweichungen erlaubt sind

### 6. User Review

Lege `sitemap.html`, die Screen-Mockups und `implementation-handoff.md` gemeinsam vor. Frage den User nicht nur nach Optik, sondern auch:
- Stimmt die wiederzuverwendende Komponentenliste?
- Sind die neuen Component Candidates akzeptiert?
- Sind Demo-only Teile korrekt abgegrenzt?

Bei Aenderungen: Mockups und Handoff gemeinsam anpassen.

### 7. Handoff

Nach Approval → Requirements Engineer (2) empfehlen. Die Mockups sind jetzt Pflicht-Input fuer User Stories, Acceptance Criteria und Edge Cases.

## Checklist vor Abschluss

- [ ] Design System Referenz geladen (falls vorhanden) und Tokens uebernommen
- [ ] Component Registry / bestehende Components gescannt
- [ ] Wichtige UI-Elemente in Mockups mit `Reuse:` oder `New candidate:` markiert
- [ ] App-Shell erkannt und in Mockups eingebettet (Header, Sidebar, Content-Area)
- [ ] Sitemap erstellt mit allen Seiten und Flows
- [ ] Mockup pro Screen erstellt
- [ ] Alle Mockups untereinander verlinkt (klickbare Navigation)
- [ ] Relevante Interaktionen mit Vanilla-JS simuliert
- [ ] CSS/JS/HTML-Primitives wiederverwendet; keine vermeidbare Duplikation
- [ ] State-Varianten (Empty, Loading, Error) vorhanden
- [ ] Source-Referenzen in Mockups eingetragen
- [ ] `implementation-handoff.md` erstellt mit Project Mode, Reuse, New Component Candidates, Design Tokens, Interaction Contract und Implementation Tolerance
- [ ] User hat Mockups reviewed und approved

## Git Commit Format

```
docs(PROJ-<X>): Add UI mockups and sitemap for <thema>
```
