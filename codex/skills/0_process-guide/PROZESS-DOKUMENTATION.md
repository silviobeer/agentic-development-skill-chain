# Entwicklungsprozess — Komplettdokumentation

> Dieses Dokument beschreibt den gesamten Skill-Chain-basierten Entwicklungsprozess, alle beteiligten Agenten, Hooks und Mechanismen.
> Stand: 2026-04-30 (Project-Mode, UI-Handoff, Wave-Gate-Config, Ken PROJ-End)

---

## Ablauf auf einen Blick

### ASCII-Flow (universell, rendert in jedem Editor)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PLANUNG (interaktiv, Mensch im Loop)                │
│                                                                             │
│  [Idee / Feature-Wunsch]                                                    │
│     │                                                                       │
│     ▼                                                                       │
│  Skill 1  Brainstorming                                                     │
│     │     Intent klären, Optionen auffächern, blinde Flecken ausleuchten.   │
│     │     → concept.md (maximal-divergente Ideenbasis)                      │
│     │                                                                       │
│     ├── Skill 1b — Visual Companion (optional, nur UI-Features)             │
│     │     Interaktive Layout-Exploration VOR Design, Mockups und            │
│     │     Requirements. Klassifiziert Project Mode: greenfield,             │
│     │     brownfield oder hybrid.                                           │
│     │     → 2_visual-companion/layout-exploration.html + decision.md        │
│     │                                                                       │
│     ├── Skill 2a — Frontend Design (optional, Greenfield/Hybrid + UI)       │
│     │     Colors/Typo/Spacing-Tokens definieren BEVOR Mockups gebaut werden.│
│     │     Bei Hybrid nur dokumentierte Design-Gaps füllen.                  │
│     │     → 4_design/design-language.md                                     │
│     │                                                                       │
│     ├── Skill 2b — UI Mockups + Sitemap (UI-Features Pflicht)               │
│     │     Lightweight HTML-Mockups + Screen-Flow-Diagramm und expliziter    │
│     │     UI Implementation Handoff für Requirements bis Execution.         │
│     │     → 5_mockups/*.html + implementation-handoff.md                    │
│     ▼                                                                       │
│  Skill 2  Requirements Engineering                                          │
│     │     Ideen + Mockups + UI-Handoff → User Stories, Acceptance Criteria, │
│     │     Edge Cases und UI Implementation Notes.                           │
│     │     → PROJ-X-PRD-*.md                                                 │
│     ▼                                                                       │
│  Skill 3  Architecture                                                      │
│     │     PM-verständliches Tech-Design pro PROJ: Frameworks, Data Model,   │
│     │     API-Boundaries, Cross-cutting Decisions. Kein Code, nur           │
│     │     Trade-off-Rationale, plus PROJ-weite UI Constraints aus Handoff.  │
│     │     → PROJ-X-architecture.md                                          │
│     ▼                                                                       │
│  Skill 4  Writing Plans                                                     │
│     │     Zerlegt US aus PRDs in parallelisierbare Waves. Jede Wave ein     │
│     │     File mit konkreten Tasks, UI-Handoff-Constraints, Smoke-Tests,    │
│     │     AC-Commands + Post-Wave-Notes-Platzhalter. Skill 5 führt sie aus. │
│     │     → PROJ-X-wave-N-plan.md + wave-gate-config.json                   │
│     ▼                                                                       │
│  [USER APPROVAL]  ◄── letzter Human-Gate vor Execution                      │
│     Entscheidet bewusst: Plan ist gut genug, ab jetzt läuft es automatisch. │
└────┬────────────────────────────────────────────────────────────────────────┘
     │
     │  Session-Start:
     │  • claude --dangerously-skip-permissions    (Zero-Prompt-Garantie)
     │  • bash scripts/merge-project-settings.sh   (Allow/Deny-Template)
     │  • .coderabbit.yaml kopieren                (per-project Review-Config)
     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      EXECUTION (automatisch, HARD-GATEs)                    │
│                                                                             │
│  Skill 5  Executing  (Orchestrator delegiert alles, niemand arbeitet inline)│
│     │     Context-Economy: Raw-Output (Diffs, Build-Logs) stirbt im         │
│     │     Subagent, Orchestrator hält nur IDs/Verdicts.                     │
│     ▼                                                                       │
│   ┌──────────────────────────────────────────────────────────────┐          │
│   │  FÜR JEDE WAVE:                                              │          │
│   │    git tag wave-N-start-PROJ-X                               │          │
│   │      │     Fixiert den Base-Commit → CodeRabbit-Review später│          │
│   │      │     nur auf THIS wave's Diff statt 20+ Commits hinten.│          │
│   │      ▼                                                       │          │
│   │    spawn implementer-Subagenten (parallel, 1 pro US)         │          │
│   │      │     frontend-/backend-/generic-implementer nach       │          │
│   │      │     US-Typ. Tests schreiben zuerst (TDD), dann Code.  │          │
│   │      ▼                                                       │          │
│   │    Ralph-Loop AC-Verification (Subagent)                     │          │
│   │      │     Jeder AC deterministisch verifiziert — max 3      │          │
│   │      │     Loops, Rest wird dokumentiert.                    │          │
│   │      ▼                                                       │          │
│   │    [GATE: bash wave-gate.sh  →  Exit 0?]                     │          │
│   │      │     Hard-Gate kombiniert AC-Status + Build +          │          │
│   │      │     CodeRabbit + Smoke. Non-zero                      │          │
│   │      │     blockiert nächste Wave (Hook erzwingt es auch).   │          │
│   │      │                │                                      │          │
│   │      │  nein          │  ja                                  │          │
│   │      └── retry ◄──────┤                                      │          │
│   │                       │                                      │          │
│   │                       ▼                                      │          │
│   │    auto-tag wave-(N+1)-start-PROJ-X                          │          │
│   │          Script setzt Tag für nächste Wave automatisch →     │          │
│   │          Main-Agent kann es ab Wave 2 nicht mehr vergessen.  │          │
│   └──────────────────────────────────────────────────────────────┘          │
│     │                                                                       │
│     ▼   (nach letzter Wave)                                                 │
│  Quality Gate:                                                              │
│     code-reviewer-gate  ┐   parallele Subagenten;                           │
│                         ├─► feature-weite Checks (nicht per-Wave).          │
│     sonar-scanner-gate  ┘   Exit: 0 P0/P1, 0 BLOCKER/CRITICAL/MAJOR.        │
│     │                                                                       │
│     ▼                                                                       │
│  [HARD-GATE]  /compact  →  /6_qa                                            │
│     Context flushen (Wave-Plans + Ralph-Logs sind auf Disk), Skill 6        │
│     braucht Budget für Playwright MCP + 6 Persona-Reviewer.                 │
│     │                                                                       │
│     ▼                                                                       │
│  Skill 6  QA   (findet & dokumentiert Bugs — fixt NIE selbst)               │
│     │                                                                       │
│     ├── Stream 1: Playwright E2E (MCP)                                      │
│     │     Browser-Driven End-to-End pro AC, auf laufendem Dev-Server.       │
│     ├── Stream 2: red-team-tester (Subagent)                                │
│     │     Injection, Auth-Bypass, Boundary-Values, Race-Conditions.         │
│     ├── Stream 3: ui-auditor (Subagent)                                     │
│     │     Design-System-Compliance + Registry-Cross-Check + Responsive/A11y.│
│     └── Stream 4: 6-Persona-Panel (Codex background OR Codex fallback)     │
│         Adversarial Code-Review: jede Persona 20 Jahre Erfahrung als Lens.  │
│         • Dr. Sarah Chen (Security)   OWASP, auth, crypto, injection, RLS   │
│         • Marcus Weber (Principal)    SOLID, Kopplung, Testbarkeit          │
│         • Priya Sharma (Performance)  Latenz, N+1, Bundle, Cache            │
│         • Thomas Müller (SRE)         Failure modes, Retries, Observability │
│         • Elena Rodriguez (Architect) Cross-Wave-Kohärenz + PROJ Retro      │
│     │                                                                       │
│     ▼                                                                       │
│  [Critical/High Bugs?]                                                      │
│     │                                                                       │
│     │  ja  → Fixer-Subagenten clustered by file  → retry QA                 │
│     │         (Disjoint-file invariant verhindert Merge-Konflikte)          │
│     │                                                                       │
│     │  nein (oder nur Medium/Low — die werden geloggt, nicht geblockt)      │
│     ▼                                                                       │
│  [HARD-GATE]  /compact  →  /7_documentation                                 │
│     Persona-Transcripts + QA-Logs flushen; Skill 7 braucht nur progress.md. │
│     │                                                                       │
│     ▼                                                                       │
│  Skill 7  Documentation (Orchestrator liest NUR progress.md — Rest         │
│     │     delegiert; würde sonst das Context-Budget sprengen).              │
│     │     Bedingt-updated: README wenn Deps-Delta; TECHNICAL wenn           │
│     │     Architecture-Delta; AGENTS.md-Merge nur nach User-Approval.       │
│     ▼                                                                       │
│  commit: docs/PROJECT.md + README.md + docs/TECHNICAL.md + AGENTS.md        │
│     ▼                                                                       │
│  [GATE: bash proj-readiness-check.sh X  →  Exit-Code?]                      │
│     Checkt ob PROJ-(X+1) fully planned (architecture + ≥1 wave plan +       │
│     PRD-Coverage). Ohne Human-Intervention weiter, nur wenn sicher.         │
│     │                                                                       │
│     ├── 0  nächster PROJ fully planned                                      │
│     │       → /compact  →  /5_executing für PROJ-(X+1)                      │
│     │       Loop zurück — ganze PROJ-Chain ohne User-Prompt.                │
│     │                                                                       │
│     ├── 1  alle PROJs fertig                                                │
│     │       → 🎉 production-ready — Chain-Ende, Summary-Report.             │
│     │                                                                       │
│     └── 2  PROJ-(X+1) unvollständig geplant                                 │
│             → STOP, Skills 3+4 manuell ausführen. Execution darf nicht auf  │
│               halb-fertigen Plans laufen — halluziniertes Chaos vermeidbar. │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Legende:**
- Vertikale Linien = Haupt-Ablauf, Text-Pfeile `▼` = HARD-GATE blockiert bis grün
- `[GATE: ...]` = Script-Hard-Gate (Exit-Code entscheidet)
- `[HARD-GATE]` = Skill-Handoff-Gate (dokumentiert in der Ziel-Skill)
- Einrückung in Subagenten-Listen = parallel gespawnt, Orchestrator sieht nur Summaries

---

### Mermaid-Diagramm (für GitHub / Mermaid-kompatible Viewer)

> VS Code braucht die Extension **"Markdown Preview Mermaid Support"** um das Diagramm unten zu rendern. Ansonsten den ASCII-Flow oben nutzen.

```mermaid
flowchart TD
    Start([Idee / Feature-Wunsch]) --> S1[Skill 1<br/>Brainstorming<br/><i>concept.md</i>]

    S1 --> S1b{UI?}
    S1b -- ja --> S1bV[Skill 1b<br/>Visual Companion<br/><i>layout + project mode</i>]
    S1b -- nein --> S2
    S1bV --> Mode{Project mode}

    S2[Skill 2<br/>Requirements Engineering<br/><i>PROJ-X-PRD-*.md</i>]
    Mode -- greenfield --> S2aF[Skill 2a<br/>Frontend Design<br/><i>design-language.md</i>]
    Mode -- hybrid mit Gaps --> S2aF
    Mode -- brownfield --> S2b
    S2aF --> S2b
    S2b[Skill 2b<br/>UI Mockup<br/><i>sitemap + mockups + UI handoff</i>] --> S2
    S2 --> S3

    S3[Skill 3<br/>Architecture<br/><i>PROJ-X-architecture.md</i>]
    S3 --> S4[Skill 4<br/>Writing Plans<br/><i>PROJ-X-wave-N-plan.md</i><br/><i>wave-gate-config.json</i>]

    %% Human gate between planning and execution
    S4 --> Approve{{User approvt<br/>Plans}}
    Approve --> Launch[claude --dangerously-skip-permissions<br/>+ bash scripts/merge-project-settings.sh<br/>+ .coderabbit.yaml]

    Launch --> S5[Skill 5 — Executing<br/>Orchestrator spawnt alles]

    subgraph WaveLoop[Per Wave]
        direction TB
        Tag[git tag wave-N-start-PROJ-X] --> Spawn[implementer-Subagenten parallel]
        Spawn --> Ralph[Ralph-Loop AC-Verification<br/>max 3 Loops]
        Ralph --> Gate{{bash wave-gate.sh<br/>ACs + Build + CodeRabbit + Smoke<br/>Exit 0?}}
        Gate -- nein --> Spawn
        Gate -- ja --> AutoTag[Auto-Tag nächste Wave]
    end

    S5 --> WaveLoop
    WaveLoop --> QG[Quality Gate<br/>code-reviewer-gate + sonar-scanner-gate<br/>parallel subagents]
    QG --> HG5[/compact → /6_qa<br/>HARD-GATE]

    HG5 --> S6[Skill 6 — QA]
    subgraph QAStreams[4 parallel Streams + 6 Personas]
        direction LR
        Pla[Playwright<br/>E2E]
        Red[red-team-tester]
        UI[ui-auditor]
        Per[6-Persona-Panel<br/>Codex background<br/>oder Codex fallback]
    end
    S6 --> QAStreams
    QAStreams --> Fix{Critical/High<br/>Bugs?}
    Fix -- ja --> FixSpawn[Fixer-Subagenten<br/>clustered by file] --> S6
    Fix -- nein --> HG6[/compact → /7_documentation<br/>HARD-GATE]

    HG6 --> S7[Skill 7 — Documentation<br/>Orchestrator liest NUR progress.md<br/>Rest delegiert]
    S7 --> Docs[docs/PROJECT.md + README.md<br/>+ docs/TECHNICAL.md + AGENTS.md]

    Docs --> Next{{bash proj-readiness-check.sh X<br/>Exit-Code?}}
    Next -- 0 nächster PROJ ready --> CompactLoop[/compact] --> S5
    Next -- 1 alles fertig --> Done([🎉 production-ready])
    Next -- 2 next PROJ<br/>unvollständig geplant --> Stop([STOP: Skills 3+4 ausführen])

    %% Styling
    classDef human fill:#fef3c7,stroke:#f59e0b,stroke-width:2px
    classDef orchestrator fill:#dbeafe,stroke:#2563eb,stroke-width:2px
    classDef subagent fill:#dcfce7,stroke:#16a34a
    classDef gate fill:#fee2e2,stroke:#dc2626,stroke-width:2px
    classDef autonomous fill:#e9d5ff,stroke:#7c3aed

    class Start,Approve human
    class S1,S1bV,S2,S2aF,S2b,S3,S4 orchestrator
    class S5,S6,S7 orchestrator
    class Spawn,FixSpawn,QAStreams,Pla,Red,UI,Per subagent
    class Gate,HG5,HG6,Next,QG gate
    class Launch,Tag,AutoTag,Docs,CompactLoop autonomous
```

**Lesehilfe:**
- 🟡 **Gelb** = Human-Input-Punkte (Ideation, Plan-Approval, Session-Start)
- 🔵 **Blau** = Skill-Orchestrator (Main-Agent, pro Skill)
- 🟢 **Grün** = Spawned Subagenten (hier passiert die eigentliche Arbeit)
- 🔴 **Rot** = Hard-Gates / Script-Exits (blockieren bis grün)
- 🟣 **Lila** = Automatische Transition (kein User-Prompt)

**Wichtige Prinzipien im Diagramm:**
1. **Planung (Skills 1–4)** bleibt interaktiv — kreative Entscheidungen brauchen Menschen.
2. **Execution (Skills 5→6→7)** läuft nach Plan-Approval voll automatisch via HARD-GATE-Kette.
3. **Orchestrator macht nichts selbst** — alles wird an Subagenten delegiert (Context Economy).
4. **Multi-PROJ:** am Ende von Skill 7 checkt `proj-readiness-check.sh`, ob der nächste PROJ fully planned ist → Loop nach Skill 5 zurück.

---

## Inhaltsverzeichnis

1. [Übersicht](#1-übersicht)
2. [Prozessschritte im Detail](#2-prozessschritte-im-detail)
3. [Die Skill Chain (Kurzreferenz)](#3-die-skill-chain-kurzreferenz)
4. [Agenten](#4-agenten)
5. [Hooks](#5-hooks)
6. [Context Management](#6-context-management)
7. [Component Registry](#7-component-registry)
8. [Memory-System (Step 5)](#8-memory-system-step-5)
9. [Quality Gates](#9-quality-gates)
10. [Referenz-Skills](#10-referenz-skills)
11. [Greenfield, Brownfield, Hybrid](#11-greenfield-brownfield-hybrid)
12. [Externe Abhängigkeiten (CLI / Plugins / MCPs)](#12-externe-abhängigkeiten-cli--plugins--mcps)

---

## 1. Übersicht

Der Prozess führt ein Feature von der Idee bis zur Dokumentation. Jede Phase hat einen eigenen Skill, der den Main Agent (oder spezialisierte Sub-Agenten) anleitet. Alle Phasen arbeiten auf denselben Spec-Dateien — ein File wächst durch die Pipeline.

```
Idee → Brainstorming → [Visual Companion] → [Design] → [Mockups] → Requirements → Architecture → Plan → Executing → QA → Docs
```

**Konventionen:**
- PROJ-Ordner: `specs/PROJ-<X>-<thema>/` (pro Initiative)
  - Concept: `1_brainstorm/PROJ-<X>-concept.md`
  - Visual Companion: `2_visual-companion/layout-decision.md` + `layout-exploration.html`
  - PRDs: `3_PRDs/PROJ-<X>-PRD-<Y>-<desc>.md`
  - Design-Language: `4_design/design-language.md`
  - Mockups: `5_mockups/*.html`
  - Architecture: `6_plan/PROJ-<X>-architecture.md`
  - Wave-Plans: `6_plan/PROJ-<X>-wave-<N>-plan.md`
  - Progress: `7_progress/PROJ-<X>-progress.md`
- Agent-Notizen: `src/features/<name>/agent.md`
- Dokumentation: `docs/PROJECT.md`
- Alle Skills und Agenten in English, Konversation auf Deutsch
- **PROJ-X** = Initiative (Thema-Container) · **PRD-Y** = einzelnes testbares Feature · **Wave-N** = Implementierungsgruppe (kann PRDs überspannen)

---

## 2. Prozessschritte im Detail

### Schritt 1 — Brainstorming

| | |
|---|---|
| **Skill** | `1_brainstorming` |
| **Wer arbeitet** | Main Agent (Opus) |
| **Sub-Agenten** | Keine |
| **Input** | Idee des Users (frei formuliert) |
| **Was passiert** | Main Agent erforscht die Idee, allokiert PROJ-X und Thema-Slug, recherchiert Kontext im Codebase, schlägt Ansätze vor, diskutiert mit dem User bis ein Concept steht |
| **Output** | `specs/PROJ-<X>-<thema>/1_brainstorm/PROJ-<X>-concept.md` |
| **Nächster Schritt** | → Schritt 1b (UI-Features) oder → Schritt 2 (Backend/API) |

---

### Schritt 1b — Visual Companion *(optional, nur UI-Features)*

| | |
|---|---|
| **Skill** | `1b_visual-companion` |
| **Wer arbeitet** | Main Agent (Opus) |
| **Sub-Agenten** | Keine |
| **Input** | Concept-Doc aus Schritt 1 |
| **Was passiert** | Main Agent diskutiert die Idee, scannt bestehende UI-Patterns und generiert mehrere interaktive Layout-Ansätze (Sidepanel, Modal, Full Page, Split View, Wizard). Dabei wird `Project Mode` als `greenfield`, `brownfield` oder `hybrid` festgelegt. User entscheidet die grobe UI-Form vor Mockup und Requirements. |
| **Output** | `specs/PROJ-<X>-<thema>/2_visual-companion/layout-exploration.html` + `layout-decision.md` |
| **Voraussetzung** | Feature hat UI-Anteil. Bei reinem Backend/API → überspringen |
| **Nächster Schritt** | → Schritt 2a (Greenfield/Hybrid mit Design-Gaps) oder → Schritt 2b (Brownfield) |

---

### Schritt 2a — Frontend Design *(optional, Greenfield oder Hybrid-Gaps)*

| | |
|---|---|
| **Skill** | `2a_frontend-design` |
| **Wer arbeitet** | Main Agent (Opus) |
| **Sub-Agenten** | Keine |
| **Input** | Concept-Doc aus Schritt 1 + Visual-Companion-Entscheidung inkl. `Project Mode` und `Shape Brief` |
| **Was passiert** | Main Agent definiert die visuelle Design-Sprache: Farbpalette, Typografie, Spacing, Tone, CSS Variables. Bei Hybrid-Projekten werden nur die dokumentierten Design-Gaps gefüllt; bestehende Tokens/Komponenten bleiben verbindlich. |
| **Output** | `specs/PROJ-<X>-<thema>/4_design/design-language.md` + angepasste `tailwind.config` / `globals.css` |
| **Voraussetzung** | Greenfield ohne Design System oder Hybrid mit relevanten Design-Gaps |
| **Nächster Schritt** | → Schritt 2b |

---

### Schritt 2b — UI Mockups *(UI-Features Pflicht)*

| | |
|---|---|
| **Skill** | `2b_ui-mockup` |
| **Wer arbeitet** | Main Agent (Opus) |
| **Sub-Agenten** | Keine |
| **Input** | Concept-Doc + Visual-Companion-Wireframe/Entscheidung, `Project Mode`, `Shape Brief`, ggf. Design Language aus Schritt 2a |
| **Was passiert** | Main Agent erstellt leichtgewichtige interaktive HTML-Mockups und eine visuelle Sitemap. Bestehende Komponenten/Farben/Schriften werden angenähert und gelabelt. Zusätzlich entsteht ein `implementation-handoff.md`, damit Requirements, Architecture, Plans und Execution nicht aus HTML raten müssen. |
| **Output** | `specs/PROJ-<X>-<thema>/5_mockups/sitemap.html` + Screen-Mockups + `implementation-handoff.md` |
| **Nächster Schritt** | → Schritt 2 |

---

### Schritt 2 — Requirements Engineering

| | |
|---|---|
| **Skill** | `2_requirements-engineer` |
| **Wer arbeitet** | Main Agent (Opus) |
| **Sub-Agenten** | Keine |
| **Input** | Concept-Doc aus Schritt 1 + Mockups/Sitemap + `implementation-handoff.md` aus Schritt 2b (bei UI-Features Pflicht) |
| **Was passiert** | Main Agent verwandelt Concept, genehmigte Mockups und UI-Handoff in eine oder mehrere PRDs: User Stories mit Acceptance Criteria, Edge Cases, Out-of-Scope-Abgrenzung und UI Implementation Notes. Eine PROJ kann 1..n PRDs haben (jedes PRD = testbares Feature). |
| **Output** | `specs/PROJ-<X>-<thema>/3_PRDs/PROJ-<X>-PRD-<Y>-<desc>.md` (pro PRD) |
| **Nächster Schritt** | → Schritt 3 |

---

### Schritt 3 — Architecture

| | |
|---|---|
| **Skill** | `3_architecture` |
| **Wer arbeitet** | Main Agent (Opus) |
| **Sub-Agenten** | Keine |
| **Referenz-Skills** | `tailwind-css` (bei Tailwind-Projekten), `nextjs-app-router-patterns` (bei Next.js-Projekten) |
| **Input** | Alle PRDs aus Schritt 2 + Mockups und `implementation-handoff.md` aus 2b bei UI-Features |
| **Was passiert** | Main Agent erstellt ein PROJ-weites PM-freundliches Tech Design, das alle PRDs der Initiative abdeckt: Komponentenstruktur, Datenmodell, API-Design, Tech-Entscheide mit Begründung. Kein Code — nur High-Level-Design. |
| **Output** | `specs/PROJ-<X>-<thema>/6_plan/PROJ-<X>-architecture.md` |
| **Nächster Schritt** | → Schritt 4 |

---

### Schritt 4 — Writing Plans

| | |
|---|---|
| **Skill** | `4_writing-plans` |
| **Wer arbeitet** | Main Agent (Opus) |
| **Sub-Agenten** | `component-scout` (Sonnet) — **immer** bei UI-Waves (greenfield oder brownfield), pflegt `docs/components.md` |
| **Referenz-Skills** | `nextjs-app-router-patterns` (bei Next.js), `tailwind-css` (bei UI-Tasks) |
| **Input** | Architecture-File aus Schritt 3 + alle PRDs, ggf. Component Registry aus `docs/components.md` |
| **Was passiert** | 1. Liest bestehende Component Registry (`docs/components.md`). 2. Bei jedem UI-Wave → spawnt `component-scout` (auch greenfield: erstellt leeres Registry-File). 3. Sammelt User Stories PROJ-weit, baut cross-PRD-Dependency-Graph, bestimmt Waves. 4. Schreibt pro Wave ein Plan-File mit TDD-Tasks, Files, Scope/Agent-Typ, **leerem Post-Wave-Notes-Platzhalter pro US** (Skill 7 harvestet Doku-Inputs nach QA). 5. Pro UI-Task **Pflicht-Section** `**Components:** Reuse: [...] — Create new: [... + 1-Zeilen-Justification]`. 6. Schreibt `wave-gate-config.json` (build_cmd, timeouts, advisory_severities, ac_commands, frontend_routes). 7. Self-Review enthält Punkt #9: Components-Section in jeder UI-Task komplett? |
| **Output** | `specs/PROJ-<X>-<thema>/6_plan/PROJ-<X>-wave-<N>-plan.md` pro Wave + `wave-gate-config.json` |
| **Nächster Schritt** | → Schritt 5 |

---

### Schritt 5 — Executing

| | |
|---|---|
| **Skill** | `5_executing` |
| **Wer arbeitet** | Main Agent (Opus) als Orchestrator |
| **Sub-Agenten (Implementierung)** | Pro User Story je nach Typ: |
| | • `frontend-implementer` (Sonnet, maxTurns 50) — reine UI-Tasks |
| | • `backend-implementer` (Sonnet, maxTurns 50) — reine Server-Tasks |
| | • `implementer` (Sonnet, maxTurns 50) — Full-Stack-Tasks |
| | • `integration-guard` (Haiku, maxTurns 20) — Read-only Konflikt-Monitor bei parallelen Waves |
| **Sub-Agenten (Quality Gate)** | Nach allen Waves, parallel: |
| | • `code-reviewer-gate` (Sonnet, maxTurns 25) — Code Review gegen Checkliste |
| | • `sonar-scanner-gate` (Sonnet, maxTurns 20) — SonarCloud Scan auf Feature-Dateien |
| **Persona Reviewer** | Kein Ken pro Wave. Per-Wave-Review ist CodeRabbit im `wave-gate.sh`. **Ken Takahashi — Minimalism Engineer (20y)** läuft nur am PROJ-Ende in Skill 6 gegen den assembled PROJ-Diff. |
| **Components Hard Rule** | Implementer-Agenten MÜSSEN vor jedem neuen Component-File (`src/components/**` oder `src/features/*/components/**`): 1) `grep` exact match, 2) `grep` semantically similar, 3) `docs/components.md` lesen, 4) reuse/extend wenn vorhanden, 5) wenn neu → Registry-Entry im **selben Commit** wie Component-File. Hook `component-registry-check.js` (PreToolUse) blockt Write/Edit, wenn Registry nicht dirty ist. Escape: `_Filename.tsx` prefix oder `<!-- registry-exempt: reason -->` in den ersten 5 Zeilen. |
| **Referenz-Skills** | `tailwind-css`, `nextjs-app-router-patterns` (werden an Implementer-Agenten übergeben) |
| **Input** | Architecture + Wave-Plans aus Schritt 4 |
| **Was passiert** | |
| | **Phase 0 — Preflight (FIRST ACTION):** **Permissions:** Codex MUSS mit `claude --dangerously-skip-permissions` gestartet werden (echte Zero-Prompt-Garantie). Als Fallback/Belt-and-Braces: `bash scripts/merge-project-settings.sh` (merged Template mit `defaultMode: bypassPermissions` in `.claude/settings.json`, deny-list blockt destruktive Ops). **CodeRabbit-Config:** fehlt `.coderabbit.yaml` am Repo-Root → aus `~/.codex/skills/5_executing/references/coderabbit-template.yaml` kopieren (`chill` profile, path_filters, path_instructions). **MCP:** Supabase + Playwright verbunden (falls Features das brauchen). **Git-Tag Wave-1-Start:** `git tag wave-1-start-PROJ-<X>` am Feature-Start (Wave 2+ setzt `wave-gate.sh` automatisch). Dann `/compact`. |
| | **Phase 1: Wave-Implementierung** — Für jede Wave im Plan: |
| | &nbsp;&nbsp;1. Teammates pro US spawnen (parallel innerhalb einer Wave) — **immer delegieren, Orchestrator schreibt keinen Code inline** (Context Economy) |
| | &nbsp;&nbsp;2. Jeder Teammate: Tests schreiben → Code implementieren → Ralph Loop (AC-Verifikation) |
| | &nbsp;&nbsp;3. Bei parallelen Waves: `integration-guard` überwacht File-Konflikte |
| | &nbsp;&nbsp;4. Wave-Ende: Ralph (max 3 Loops, Rest dokumentieren) → **`bash scripts/wave-gate.sh <N> <PROJ-X> <thema>`** (ACs + Build + CodeRabbit + Smoke, HARD-GATE, Exit 0) |
| | &nbsp;&nbsp;5. `wave-gate.sh` — **Base-SHA-Resolution:** `$WAVE_BASE_SHA` env > git-tag `wave-N-start-PROJ-X`; fehlt beides → harter Fail. Kein commit-msg/`HEAD~20`/root-Fallback. Nach PASSED taggt das Script automatisch HEAD als `wave-(N+1)-start-PROJ-X` für die nächste Wave (idempotent). Appendet minimalen PASSED-Block; Skill 7 sammelt Doku-Inputs später selbst. |
| | &nbsp;&nbsp;6. Fail-Safe: PreToolUse-Hook `wave-gate-enforcer.js` blockiert implementer-Spawns für Wave N+1, falls `### Wave N Gate — PASSED`-Block fehlt |
| | **Phase 2: Quality Gate** — Nach allen Waves: |
| | &nbsp;&nbsp;1. `code-reviewer-gate` + `sonar-scanner-gate` parallel spawnen — **niemals inline** |
| | &nbsp;&nbsp;2. Exit-Kriterium: Zero P0/P1 (Code Review) + Zero BLOCKER/CRITICAL/MAJOR (Sonar) |
| | &nbsp;&nbsp;3. Bei Findings: Fixer-Subagenten spawnen (geclustert nach file), dann erneut prüfen |
| | **Phase 3: Handoff zu Skill 6** — HARD-GATE: `/compact` → `/6_qa` aufrufen. **Nicht überspringen**, auch wenn Step 10 QA 0 Bugs hatte (Skill 6 liefert Retrospektive + AGENTS.md-Kandidaten für Skill 7). |
| **Output** | Implementierter Code + Tests + Commits (`feat(PROJ-<X>-PRD-<Y>): ...`), `specs/PROJ-<X>-<thema>/7_progress/PROJ-<X>-progress.md` |
| **Nächster Schritt** | → Schritt 6 (via HARD-GATE, automatisch) |

---

### Schritt 6 — QA

| | |
|---|---|
| **Skill** | `6_qa` |
| **Wer arbeitet** | Main Agent (Opus) als Lead + Sub-Agenten + 6 Persona-Reviewer |
| **Sub-Agenten** | Parallel: |
| | • `red-team-tester` (Sonnet, maxTurns 30) — Adversarial Testing |
| | • `ui-auditor` (Sonnet, maxTurns 25) — Design System Compliance + **harter Registry-Check**: jede neue Component in `docs/components.md` vorhanden? (sonst Critical Bug), plus semantische Duplikat-Suche + `/dev/components` Playwright-Check |
| **Persona Code Review Panel** | Sechs 20-jährige Veteranen, parallel via Codex-Companion-Script (`node "$COMPANION" adversarial-review --background`; Slash-Commands `/codex:*` haben `disable-model-invocation: true` und können NICHT aus einem Skill aufgerufen werden — daher direkt das Companion-Script via Bash) oder Codex-Subagent-Fallback: |
| | • **Dr. Sarah Chen** — Security Lead (OWASP, auth, crypto, injection, RLS) |
| | • **Marcus Weber** — Principal Engineer (SOLID, Kopplung, Fehlerbehandlung, Testbarkeit, **Component-Re-Invention-Detection**: wurde bestehende Component ignoriert?) |
| | • **Priya Sharma** — Performance Engineer (Latenz, N+1, Bundle, Cache) |
| | • **Thomas Müller** — SRE / Reliability (Failure modes, Retries, Idempotenz, Observability, Races) |
| | • **Elena Rodriguez** — Principal Architect (PROJ-Retrospektive: Cross-Wave-Kohärenz, Scope-Creep, Fundament-Qualität; schreibt `## PROJ Retrospective` in progress.md) |
| | • **Ken Takahashi** — Minimalism Engineer (YAGNI, Duplication, "earns this code its keep?", nur PROJ-Ende) |
| **Input** | Implementierter Code aus Schritt 5, alle PRDs aus `3_PRDs/`, progress.md |
| **Was passiert** | QA-Streams parallel: |
| | **Stream 1 (Main Agent):** Browser E2E Tests mit Playwright MCP — testet jeden AC im Browser auf dem Dev-Server |
| | **Stream 2 (`red-team-tester`):** Injection-Attacks, Auth-Bypass, Boundary Values, Race Conditions |
| | **Stream 3 (`ui-auditor`):** Design System Compliance, Registry Cross-Check, Responsive, A11y |
| | **Stream 4 (6 Personas):** Adversarial Code Review aus je einer Disziplin, 20 Jahre Berufserfahrung als Lens |
| | **AGENTS.md Candidates:** alle Streams (Personas + Quality-Gate-Agenten) tragen projektweite Erkenntnisse in `7_progress/PROJ-<X>-progress.md` unter `## AGENTS.md Candidates` ein — Skill 7 fragt später User-Approval pro Eintrag ab. |
| | **Fix Loop:** Critical/High Bugs → sofort fixen → re-testen. Medium/Low → User entscheidet. |
| **Output** | `## QA Test Results`-Section pro PRD (`3_PRDs/PROJ-<X>-PRD-<Y>-*.md`), PROJ-weite QA-Summary + `## PROJ Retrospective` + `## AGENTS.md Candidates` in `7_progress/PROJ-<X>-progress.md` |
| **Handoff (HARD-GATE)** | Nach QA (pass ODER nur Medium/Low verbleibend) MUSS Skill 6 `/compact` → `/7_documentation` aufrufen — kein "ready for release" Exit, keine User-Rückfrage. Blocker-Exit nur bei Critical/High, die nach Fix-Versuchen nicht weg sind. |
| **Nächster Schritt** | → Schritt 7 (automatisch via HARD-GATE) oder → Fix Loop (bei Critical/High-Blockern) |

---

### Schritt 7 — Documentation

| | |
|---|---|
| **Skill** | `7_documentation` |
| **Wer arbeitet** | Main Agent (Opus) |
| **Sub-Agenten** | Keine |
| **Input (Context Economy)** | Orchestrator liest zuerst `7_progress/PROJ-<X>-progress.md`: Wave-PASSED-Blocks, `BASE_SHA`, `## AGENTS.md Candidates`, `## PROJ Retrospective`, `## QA Results`. Skill 7 harvestet Shipped/Deps/Gotchas danach aus Wave-Plans, package.json-Diff, agent.md, Progress und Commits. **Fallback:** fehlen `## PROJ Retrospective` / `## AGENTS.md Candidates` (z.B. Skill 6 lief nur CLI-Checklist ohne 6-Persona-Panel) → degraded-input path, Retrospektive leer, §5 AGENTS.md-Merge übersprungen, Final-Summary notiert es. Kein Fail. |
| **Was passiert** | **Drei-Output-Modell, bedingtes Update:** |
| | • `README.md` (Projekt-Root, ≤ 50 Zeilen) — aktualisiert **nur** bei Deps-Delta oder erstem PROJ |
| | • `docs/PROJECT.md` — **immer** aktualisiert, Feature-Katalog, 5-10 Zeilen pro PROJ, Link zu PRDs |
| | • `docs/TECHNICAL.md` — aktualisiert bei Architecture-Änderung, `agent.md`-Delta oder Deps-Delta; führt Cross-cutting Decisions, Data Model, Gotchas, Deployment |
| | • `AGENTS.md` (Projekt-Root, **hartes 40-Zeilen-Limit**) — User-Approval pro Kandidat via `AskUserQuestion`; approvierte Einträge werden gemerged, bei Cap-Überschreitung zeigt Skill 7 alte Einträge zum Entfernen |
| **Output** | README.md / docs/PROJECT.md / docs/TECHNICAL.md / AGENTS.md — nur geänderte Files. Ein Commit: `docs(PROJ-<X>): Update project documentation` |
| **Handoff (HARD-GATE)** | Nach Commit: `bash scripts/proj-readiness-check.sh <X>`. **Exit 0** (nächster PROJ fully planned) → `/compact` **dann** `/5_executing` für PROJ-<X+1> automatisch, keine User-Rückfrage. **Exit 1** (keine weitere PROJ) → Production-ready-Meldung. **Exit 2** (PROJ-<X+1> unvollständig geplant, architecture.md oder wave plans fehlen) → STOP, User-Hinweis auf Skills 3+4. |
| **Nächster Schritt** | → PROJ-<X+1> (auto-continue) ODER Feature ist **production-ready** 🎉 |

---

### Meta-Skill: `autonomous-execution` (optional)

Orchestriert Skills 5 → 6 → 7 ohne User-Prompts. Setzt `CODEX_AUTONOMOUS_LEVEL=conservative|balanced|aggressive` (Default **balanced**) und ruft die drei Skills sequenziell auf. Die Skills prüfen die Env-Variable an allen `AskUserQuestion`-Callsites und ersetzen sie durch Default-Policy + Audit-Log-Eintrag.

**Entry Gate:** wave plans + architecture + wave-gate-config müssen existieren, sonst halt.

**Policy-Matrix (balanced Default):**

| Decision | Policy |
|---|---|
| Ken PROJ-End Critical/High | auto-fix, nach 3 fehlgeschlagenen Fixes dokumentieren und weiter nach QA-Policy |
| QA Critical/High bugs | auto-fix, halt nach 3 fehlgeschlagenen Fixes |
| QA Medium/Low bugs | log-only (kein Fix) |
| AGENTS.md Candidates | auto-merge high-confidence (≥ 2 Persona-Quellen ODER Security/DB-Domain); Rest rejected |
| 40-Zeilen-Cap-Overflow | älteste `[MERGED]`-Einträge evikten |
| Wave-Gate-Failure | halt nach 3 consecutive Failures |
| systematic-debugging 3-Fix-Rule | halt sofort (hart in allen Levels) |

**Harte Stops in allen Levels:** 3-Fix-Rule, Build-broken ≥ 3 Waves, Security Critical ohne Auto-Fix-Pfad, Git-Konflikt auf eigenen Commits, Wave-Gate-Threshold überschritten, fehlende externe Dependency mid-run.

**Audit:** `specs/PROJ-<X>-<thema>/7_progress/PROJ-<X>-autonomous-log.md` — append-only, jeder Auto-Entscheid mit Timestamp/Context/Policy-Zeile/Outcome/Why.

**Skills 1-4 bleiben interaktiv** — Brainstorming, Requirements, Architecture, Plans brauchen menschliches Urteil, das autonomous-execution nicht ersetzt.

**Permissions — zwei Pfade:**

| Pfad | Setup | Prompt-Verhalten | Sicherheitsnetz |
|---|---|---|---|
| **A (Default, empfohlen)** | `settings.json` `permissions.allow`/`deny` (bereits hinzugefügt) + `mode: "bypassPermissions"` auf Subagent-Spawns | 0 Prompts für gelistete Ops | Deny-Liste blockt `rm -rf`, `git push --force`, `supabase db reset`, `sudo`, `mkfs` etc. |
| **B (Yolo)** | `claude --dangerously-skip-permissions` beim Start | 0 Prompts für alles | Keines — Model könnte halluzinierte `rm -rf /` ausführen |

Pfad A ist Default weil der Allowlist interaktiven Betrieb auch profitiert (kein Prompt für `git status`, `npm test`, etc.) und die Deny-Liste Unfälle verhindert. Pfad B nur für Wegwerf-Sandboxes/ephemere VMs.

---

### Zusammenfassung: Agent-Einsatz über alle Schritte

```
Schritt  Skill                   Main Agent    Sub-Agenten
───────  ──────────────────────  ────────────  ──────────────────────────────────────
  1      brainstorming           Opus          —
  1b     visual-companion        Opus          —
  2      requirements-engineer   Opus          —
  2a     frontend-design         Opus          —
  2b     ui-mockup               Opus          —
  3      architecture            Opus          —
  4      writing-plans           Opus          component-scout (Sonnet, bei Bedarf)
  5      executing               Opus (Orch.)  frontend-/backend-/implementer (Sonnet)
                                               integration-guard (Haiku)
                                               code-reviewer-gate (Sonnet)
                                               sonar-scanner-gate (Sonnet)
  6      qa                      Opus (Lead)   red-team-tester (Sonnet)
                                               ui-auditor (Sonnet)
                                               6 Persona Reviewer (Codex oder Claude):
                                                 Dr. Sarah Chen (Security)
                                                 Marcus Weber (Principal Eng.)
                                                 Priya Sharma (Performance)
                                                 Thomas Müller (SRE/Reliability)
                                                 Elena Rodriguez (PROJ Retrospective)
  7      documentation           Opus          —
```

---

## 3. Die Skill Chain (Kurzreferenz)

### Vollständige Chain

| Step | Skill | Pflicht? | Beschreibung | Output |
|------|-------|----------|--------------|--------|
| 1 | `brainstorming` | Ja | Idee erforschen, Kontext recherchieren, Ansätze vorschlagen | `1_brainstorm/PROJ-<X>-concept.md` |
| 1b | `visual-companion` | Optional bei UI | Interaktive Layout-Exploration + Project Mode (`greenfield`/`brownfield`/`hybrid`) | `2_visual-companion/layout-exploration.html` + `layout-decision.md` |
| 2a | `frontend-design` | Optional | Design-Sprache definieren: Greenfield vollständig, Hybrid nur Gaps | `4_design/design-language.md` |
| 2b | `ui-mockup` | Pflicht bei UI | Leichtgewichtige HTML-Mockups, Sitemap und UI Implementation Handoff | `5_mockups/sitemap.html` + Screen-Mockups + `implementation-handoff.md` |
| 2 | `requirements-engineer` | Ja | Concept + Mockups + UI-Handoff → User Stories, ACs, Edge Cases, UI Notes | `3_PRDs/*.md` |
| 3 | `architecture` | Ja | PM-freundliches Tech Design plus PROJ-weite UI Constraints | `6_plan/PROJ-<X>-architecture.md` |
| 4 | `writing-plans` | Ja | Wave-Pläne mit TDD-Zyklen, Dependencies, UI-Handoff-Constraints und Gate Config | `6_plan/PROJ-<X>-wave-<N>-plan.md` + `wave-gate-config.json` |
| 5 | `executing` | Ja | Implementierung mit Agent-Teams, TDD, Ralph Loops, Quality Gate | Code + Tests + Commits |
| 6 | `qa` | Ja | E2E-Tests gegen Acceptance Criteria, Security Audit | Fügt QA Results zur Spec hinzu |
| 7 | `documentation` | Ja | Projekt-Dokumentation: Architektur, Features, aktueller Stand | `docs/PROJECT.md` |

### Wann wird Step 2a empfohlen?

Bei **Greenfield-Projekten** ohne bestehendes Design System und bei **Hybrid-Projekten** mit dokumentierten Design-Gaps. Der Process Guide nutzt zuerst `layout-decision.md`:
- `Project Mode: greenfield` → `frontend-design`
- `Project Mode: hybrid` + Design-Gaps → leichtes `frontend-design`
- `Project Mode: brownfield` → `frontend-design` überspringen

Fallback, wenn `Project Mode` fehlt: App-Shell, Komponenten, Tokens, CSS Variablen, Tailwind Theme und reale Screens scannen.

### Automatische Erkennung

Der `/process-guide` Skill erkennt den aktuellen Stand anhand vorhandener Artefakte:
- Concept-Docs → Step 1 erledigt
- Visual Companion in `2_visual-companion/` inkl. Project Mode → Step 1b erledigt
- Design-Language-Datei → Step 2a erledigt
- Mockups + `implementation-handoff.md` → Step 2b erledigt
- PRDs mit User Stories → Step 2 erledigt
- Architecture-Datei → Step 3 erledigt
- Wave-Pläne + `wave-gate-config.json` → Step 4 erledigt
- `feat(PROJ-X)` Commits im Git Log → Step 5 erledigt
- QA Results in Spec → Step 6 erledigt
- Feature in `docs/PROJECT.md` dokumentiert → Step 7 erledigt

---

## 4. Agenten

### Implementierungs-Agenten (Step 5)

| Agent | Modell | maxTurns | Einsatz |
|-------|--------|----------|---------|
| `implementer` | Sonnet | 50 | Generischer Full-Stack TDD-Implementer |
| `frontend-implementer` | Sonnet | 50 | UI-spezialisiert: React, Tailwind, Next.js App Router. Hat Tailwind + Next.js Skills geladen. |
| `backend-implementer` | Sonnet | 50 | API Routes, Server Actions, DB-Schemas, RLS Policies |
| `integration-guard` | Haiku | 20 | Read-only Konflikt-Monitor bei parallelen Waves. Erkennt File-Overlap zwischen Teammates. |

**Wie der richtige Implementer gewählt wird:**
- US betrifft nur UI → `frontend-implementer`
- US betrifft nur Server-Seite → `backend-implementer`
- US ist Full-Stack → `implementer`

Der Plan (Step 4) definiert den Agent-Typ pro User Story in der Dependency-Tabelle.

### Quality Gate Agenten (Step 5, nach allen Waves)

| Agent | Modell | maxTurns | Einsatz |
|-------|--------|----------|---------|
| `code-reviewer-gate` | Sonnet | 25 | Vollständiges Code Review gegen Checkliste (P0-P3 Klassifizierung) |
| `sonar-scanner-gate` | Sonnet | 20 | SonarCloud Scan + Issue-Filterung auf Feature-Dateien |

Beide laufen **parallel** als Team. Exit-Kriterien: Zero P0/P1 + Zero BLOCKER/CRITICAL/MAJOR.

### QA Agenten (Step 6)

| Agent | Modell | maxTurns | Einsatz |
|-------|--------|----------|---------|
| `red-team-tester` | Sonnet | 30 | Adversarial Testing: Injection, Auth-Bypass, Boundary Values, Race Conditions |
| `ui-auditor` | Sonnet | 25 | Design System Compliance, Component Registry Check, Responsive Testing |

Beide laufen **parallel** als Team, während der Lead Browser E2E Tests mit Playwright MCP macht.

### Utility Agenten

| Agent | Modell | maxTurns | Einsatz |
|-------|--------|----------|---------|
| `component-scout` | Sonnet | 30 | Scannt Codebase nach UI-Components, erstellt Registry + Showcase. Wird von Step 4 (Writing Plans) gespawnt wenn keine Registry existiert. |

### Context Control bei Agenten

Alle Agenten die grosse Outputs verarbeiten haben **Context-Pruning-Anweisungen**:

- **code-reviewer-gate:** Diffs in Chunks lesen, file-by-file reviewen, raw Diff nach Extraktion droppen
- **sonar-scanner-gate:** JSON erst filtern, dann klassifizieren, raw JSON nicht behalten
- **red-team-tester:** Eine Angriffskategorie nach der anderen, verbose Outputs sofort zusammenfassen
- **ui-auditor:** Kategorie für Kategorie auditen, grep-Outputs sofort auf file:line reduzieren

---

## 5. Hooks

Sechs Hooks in `~/.claude/hooks/` registriert in `settings.json`:

### Context Statusline (`context-statusline.js`)
- **Typ:** statusLine
- **Was:** Zeigt `Model | Dir | ████████░░ 80%` in der Statusline
- **Wie:** Berechnet Context-Nutzung, normalisiert auf nutzbaren Bereich (abzüglich 16.5% Autocompact-Buffer), schreibt Bridge-File nach `/tmp/claude-ctx-{session_id}.json`

### Context Monitor (`context-monitor.js`)
- **Typ:** PostToolUse
- **Was:** Warnt den Agent wenn Context knapp wird
- **Schwellenwerte:**
  - **≤35% remaining → WARNING:** Aktuelle Arbeit abschliessen, nichts Neues starten
  - **≤25% remaining → CRITICAL:** Stop, State sichern, User informieren
- **Debounce:** 5 Tool-Calls zwischen Warnungen, Severity-Eskalation umgeht Debounce
- **Kontext-sensitiv:** Erkennt ob `progress.md` existiert und gibt spezifische Anweisungen (z.B. "update progress.md, keine neuen Waves starten")

### Prompt Injection Guard (`prompt-guard.js`)
- **Typ:** PreToolUse
- **Was:** Scannt Write/Edit-Operationen an Context-Dateien nach Injection-Patterns
- **Wo:** `specs/`, `agent.md`, `progress.md`, `SKILL.md`, `.claude/agents/`, `.codex/skills/`
- **Patterns:** 14 Regex-Patterns (z.B. "ignore previous instructions", unsichtbare Unicode-Zeichen)
- **Verhalten:** Advisory-only — blockiert nicht, warnt

### Commit Validator (`validate-commit.sh`)
- **Typ:** PreToolUse
- **Was:** Erzwingt Conventional Commits Format
- **Format:** `<type>(<scope>): <subject>` — max 72 Zeichen
- **Gültige Types:** feat, fix, docs, style, refactor, perf, test, build, ci, chore
- **Verhalten:** Blockiert (exit 2) bei ungültigem Format

### Wave Gate Enforcer (`wave-gate-enforcer.js`)
- **Typ:** PreToolUse
- **Was:** Sicherheitsnetz, das den Wave-Gate nicht umgehbar macht, auch nicht durch den Main-Agent
- **Trigger:** Jeder `Agent`-Spawn mit `subagent_type ∈ {implementer, backend-implementer, frontend-implementer}`
- **Logik:** Extrahiert aus dem Agent-Prompt die Wave-Nummer N (via `wave-<N>-plan.md` oder `Wave <N>`). Bei N > 1 prüft der Hook, ob in `specs/PROJ-<X>-<thema>/7_progress/PROJ-<X>-progress.md` ein `### Wave <N-1> Gate — PASSED`-Block existiert. Fehlt er → blockiert (exit 2) mit klarer Anleitung, `bash scripts/wave-gate.sh <N-1> ...` zuerst laufen zu lassen
- **Verhalten:** Blockiert nur Implementer-Spawns für Nicht-Erst-Waves; Non-Agent-Tool-Calls und Nicht-Implementer-Agenten gehen durch
- **Ziel:** `wave-gate.sh` ist die primäre Prüfung; dieser Hook ist die Fail-Safe-Schicht

### Component Registry Check (`component-registry-check.js`)
- **Typ:** PreToolUse
- **Was:** Blockt Write/Edit auf **neue** `.tsx/.jsx/.vue/.svelte`-Files in `src/components/**` oder `src/features/*/components/**`, falls `docs/components.md` nicht im selben Commit-Fenster aktualisiert wurde
- **Check:** `git status --porcelain -- docs/components.md` — Registry muss staged oder modified sein
- **Trigger nur auf NEUE Files:** wenn Datei bereits existiert → durchlassen (kein Edit-Block)
- **Escape-Hatches:** (1) Filename beginnt mit `_` (z. B. `_LocalHelper.tsx`), (2) HTML-Kommentar `<!-- registry-exempt: <reason> -->` in den ersten 5 Zeilen der Datei
- **Verhalten:** Block mit Exit 2 + JSON-Decision, Fehlermeldung zeigt die drei Optionen (Reuse / Registry-Entry ergänzen / Exempt)
- **Ziel:** Component-Re-Invention und fehlende Registry-Einträge mechanisch verhindern; Ergänzung zur Implementer-Hard-Rule und zum ui-auditor-Check

---

## 6. Context Management

### Problem
Die Skill Chain kann in einer langen Session den Context Window füllen. Steps 1-4 hinterlassen grosse Artefakte im Kontext, die Step 5 nicht mehr braucht (sie sind auf Disk).

### Lösung: Mehrstufig

1. **`/compact` vor Step 5:** Der Executing Skill hat als Step 0 im HARD-GATE einen `/compact`-Aufruf. Flusht den bisherigen Kontext bevor die context-intensivste Phase beginnt.

2. **Context Monitor Hook:** Warnt den Agent aktiv wenn der Context knapp wird (35% / 25% Schwellenwerte). Der Agent soll dann:
   - Aktuelle Wave abschliessen
   - `progress.md` updaten
   - User informieren → neue Session starten, von `progress.md` weitermachen

3. **Agent maxTurns:** Jeder Agent hat ein Turn-Limit als Sicherheitsnetz:
   - Implementer: 50
   - Gate-Agenten: 20-25
   - Tester: 25-30
   - Integration Guard: 20

4. **Context-Pruning in Agenten:** Agenten die grosse Outputs verarbeiten haben Anweisungen, Daten schrittweise zu verarbeiten und raw Output nach Extraktion zu droppen.

---

## 7. Component Registry

### Problem
Implementer-Agenten erstellen ständig neue UI-Elemente statt existierende Components zu nutzen **und** vergessen, neue Components im Registry einzutragen.

### Lösung: 3-Ebenen-Enforcement (Prävention + Durchsetzung + Kontrolle)

**Kanonische Registry:** `docs/components.md` — lebendes Inventar aller UI-Components:
- Name, Pfad, Purpose, 1-Zeilen-Props-Summary, Usage-Count
- Unterteilt in: UI Primitives (shadcn), Custom Components, Page-Level Components
- "Component Candidates" — Patterns die 3+ mal vorkommen und extrahiert werden sollten

**Showcase Page** — Visuelle Gallery aller Components:
- Dev-only Route (`/dev/components` — z. B. `src/app/(dev)/components/page.tsx`)
- Zeigt alle Variants/States jeder Component

**Component Scout Agent (Sonnet)** — pflegt `docs/components.md`:
- Erkennt Projektstruktur automatisch (`src/components/`, `components/`, `packages/ui/`)
- Scannt nach existierenden Components + Reuse-Opportunities
- **Wird IMMER bei UI-Waves gespawnt** (nicht nur bei Brownfield). Greenfield: erstellt leeres Registry-File.

### Drei-Ebenen-Enforcement

**Ebene 1 — Prävention (Skill 4, `writing-plans`):**
Pro UI-Task im Wave-Plan Pflicht-Section:
```markdown
**Components:**
- Reuse: Button, Card, FormField
- Create new: PriceBadge — no monetary display primitive exists yet
```
Self-Review #9 blockt den Plan, wenn eine UI-Task die Section nicht komplett ausgefüllt hat.

**Ebene 2 — Durchsetzung (Skill 5, Implementer):**
Hard Rule in `implementer.md`, `frontend-implementer.md`, `backend-implementer.md`: vor jedem neuen Component-File exakte + semantische Grep-Suche + Registry lesen + reuse/extend bevorzugen + Registry-Entry im selben Commit wie Component-File.
Mechanische Absicherung: PreToolUse-Hook `component-registry-check.js` blockt Write/Edit auf neue `.tsx/.jsx/.vue/.svelte`-Files in `src/components/**` oder `src/features/*/components/**`, wenn `docs/components.md` nicht staged/modified ist. Escape: `_Filename` prefix oder `<!-- registry-exempt: reason -->`.

**Ebene 3 — Kontrolle (Skill 6, QA):**
`ui-auditor` führt drei harte Checks aus:
1. Jede neue Component-Datei (seit Base-SHA) hat einen Entry in `docs/components.md` → sonst Critical Bug.
2. Semantische Duplikat-Suche im Registry (z. B. zwei Components mit Purpose „display price").
3. `/dev/components` Showcase-Route via Playwright rendert jede registrierte Component fehlerfrei.

Zusätzlich persona-basiert: **Marcus Weber** prüft aktiv auf Re-Invention — wurde eine existierende Component ignoriert statt wiederverwendet?

### Flow

| Step | Was passiert |
|------|-------------|
| **4 (Writing Plans)** | Spawnt `component-scout` bei jedem UI-Wave. Liest/aktualisiert `docs/components.md`. Pflegt Components-Section pro UI-Task. |
| **5 (Executing)** | Implementer-Agenten folgen Hard Rule (grep → registry → reuse/extend → neuen Entry im selben Commit). Hook `component-registry-check.js` blockt Verstösse mechanisch. |
| **6 (QA)** | `ui-auditor` cross-checkt Registry-Coverage + semantische Duplikate + Showcase-Rendering. Marcus Weber detectiert Re-Invention. |

---

## 8. Memory-System (Step 5)

Zwei Dateien werden während der Implementierung gepflegt:

### `progress.md` (kurzfristiges Gedächtnis)
- Lebt in `specs/` neben dem Plan
- Trackt: Task-Completion, Test-Status, AC-Verifikation, Blocker
- Wird nach **jedem** Task, Ralph-Iteration und Blocker aktualisiert
- Format: Tabellen mit ✓/✗/— Status pro Task und AC
- Enthält Wave Completion Checklisten, Quality Gate Ergebnisse, QA Results

### `agent.md` (langfristiges Gedächtnis)
- Lebt im Feature-Source-Ordner (z.B. `src/features/deliveries/agent.md`)
- Wird geschrieben wenn ein Agent auf ein Problem stösst und einen Workaround findet
- Format: Gotchas, Patterns die funktionieren, Dead Ends
- Wird von nachfolgenden Agenten und Sessions gelesen

---

## 9. Quality Gates

### Pro Wave (im Executing Skill)

Jede Wave durchläuft nach der Implementierung (alle HARD-GATES):

```
1. Ralph Loop              — AC-Verifikation mit echten Test-Commands, max 3 Loops
2. wave-gate.sh            — validiert ACs + Build + CodeRabbit + Smoke einmal am Wave-Ende
                              CodeRabbit blockt alle nicht-advisory Severities aus Config
3. wave-gate-enforcer.js   — PreToolUse-Hook blockt nächste Wave, wenn
                              PASSED-Block fehlt (Fail-Safe)
```

**Wave Completion Checklist** (wird automatisch von `wave-gate.sh` in `progress.md` geschrieben):
```
### Wave N Gate — PASSED (2026-04-17T...)
- [x] Ralph: N AC commands green
- [x] Build: `npm run build`
- [x] CodeRabbit: 0 non-advisory findings (advisory severities: medium,low)
- [x] Smoke: <routes oder backend-only>
```

Diese strukturierten Blöcke sind die **primären Eingaben für Skill 7 (Documentation)** — statt git log / Code-Scan.

### Nach allen Waves: Quality Gate

Zwei Gate-Agenten laufen parallel:

| Gate | Agent | Prüft | Exit-Kriterium |
|------|-------|-------|----------------|
| Code Review | `code-reviewer-gate` | Full Feature Diff gegen Checkliste (Architecture, SOLID, Security, Performance) | Zero P0 + P1 |
| SonarCloud | `sonar-scanner-gate` | Static Analysis auf Feature-Dateien | Zero BLOCKER/CRITICAL/MAJOR |

### Preflight-Check beim Execution-Start

Skill 5 (und autonomous-execution) prüfen beim Einstieg, bevor Teammates gespawnt werden:

- **Supabase MCP** (`mcp__claude_ai_Supabase__*`): verfügbar, falls `package.json` ein `@supabase/*`-Paket hat ODER ein `supabase/`-Ordner existiert
- **Playwright MCP** (`browser_navigate`, `browser_snapshot`, …): verfügbar, falls irgendeine Wave in `wave-gate-config.json` non-empty `frontend_routes` hat — ohne das scheitert Skill 6 QA mid-run
- **CLIs** via `command -v`: `agent-browser`, `coderabbit`, `jq`

Fehlt etwas → **STOP** mit Anweisung (z. B. „Reconnect Supabase MCP via `claude mcp list`"). Fail fast ist wichtig, weil ein Finding nach Stunde 2 im autonom-Lauf katastrophal ist.

### Browser-Testing: Doktrin

Zwei Tools, klare Rollen:

| Tool | Einsatz | Warum |
|---|---|---|
| **agent-browser** (CLI) | Per-Wave Smoke-Tests in Skill 5, `wave-gate.sh`-Smoke, Dev-Server-Post-Start-Gut-Check | Läuft ohne MCP-Context, delegiebar an Subagent, schnell (60 s) |
| **Playwright MCP** (browser_*) | QA-E2E in Skill 6: jeder AC, Form-Fills, Multi-Step-Flows, Snapshot-Evidence, Console-/Network-Inspection | Reiche Interaktion + State-Assertion nötig |

**Entscheidungsregel:** State-Assertion / Multi-Step-Flow / Screenshot-Evidence nötig → Playwright MCP. Sonst → agent-browser.

### Finding-IDs und Anchors (Context-Ökonomie für Fixer-Agenten)

Jedes Finding (Bug, AGENTS.md-Kandidat, CodeRabbit/Sonar-Issue) bekommt beim Erstellen eine **stabile ID**, die als Referenz-Handle für Fixer-Spawns dient. Der Main-Agent ruft Fixer mit nur den relevanten IDs + Anchors im Prompt auf — nicht mit der vollständigen Finding-Liste. Das hält Subagent-Context ≤ 2000 Tokens statt 20000.

**ID-Format:**

| Quelle | Schema | Beispiel |
|---|---|---|
| QA-Personas + Red-Team + UI-Auditor | `BUG-PROJ<X>-QA-<NNN>` | `BUG-PROJ1-QA-042` |
| CodeRabbit pro Wave | `BUG-PROJ<X>-W<N>-CR<NNN>` | `BUG-PROJ1-W2-CR007` |
| SonarCloud (Quality Gate) | `BUG-PROJ<X>-SONAR-<NNN>` | `BUG-PROJ1-SONAR-012` |
| AGENTS.md-Kandidaten | `AGENTS-PROJ<X>-QA-<NNN>` | `AGENTS-PROJ1-QA-003` |

`NNN` ist zero-padded, fortlaufend innerhalb der Quelle und Wave/QA-Run.

**Pflichtfelder pro Finding in `progress.md`:**

- `id` — stabile Referenz, siehe oben
- `severity` — Critical / High / Medium / Low
- `file` — Pfad zur betroffenen Datei
- `anchor` — Symbol oder Regex (z. B. `export function validateSession`), **nicht** Line-Number. Stabil bei parallelen Fixern, die die Datei editieren.
- `source` — Persona / Agent, die das Finding erzeugt hat
- `status` — `open | in-progress | fixed | accepted | rejected`
- `fix_attempts` — Zähler für 3-Fix-Rule im Autonom-Modus

**AGENTS.md-Einträge** werden beim Merge mit HTML-Kommentar-Anchor versehen: `<!-- AGENTS-PROJ1-QA-003 -->`. Skill 7 erkennt so Duplikate bei späteren Läufen und schlägt den gleichen Kandidaten nicht erneut vor.

**Warum Anchor statt Line-Number:** mehrere parallele Fixer, die dieselbe Datei editieren, verschieben Zeilennummern. Ein Symbol/Regex-Anchor bleibt stabil — Fixer re-lokalisiert vor dem Edit per `grep`.

**Warum Markdown (und nicht JSON):** Für ≤ 20 Findings pro Lauf ist Markdown ausreichend. IDs + Status-Flags sind per `grep -E "^### BUG-PROJ1-QA-042"` eindeutig findbar. Wenn Finding-Mengen steigen (> 50 pro Run) oder parallele Schreiber zum Race-Problem werden, lohnt sich ein Wechsel auf `findings-<scope>.json` mit Schema — dann mit Lock/Queue-Handling.

### Parallele Fixer-Spawns

Fixer-Subagenten laufen **immer parallel, wenn die Dateien disjunkt sind**. Main-Agent-Algorithmus:

1. Lies alle offenen BUG-IDs aus `progress.md` (Filter: `status=open`, Severity passend zum Gate).
2. Cluster nach `file`-Feld — ein Cluster pro Datei. Cross-File-Bugs landen im Cluster ihrer Primary-File mit Hinweis im Prompt.
3. Spawn alle Cluster in **einem einzigen `Agent`-Tool-Batch** (mehrere Tool-Calls in einer Message = Claude führt parallel aus).
4. Pro Subagent: `subagent_type` = `frontend-implementer` | `backend-implementer` je nach Dateityp. Prompt enthält nur Cluster-IDs + Anchors + relevanten `agent.md`-Auszug (≤ 2000 Tokens).
5. `integration-guard` (Haiku, read-only) parallel, überwacht `git status` auf Kollisionen, die die Cluster-Logik übersehen hat.
6. Main-Agent sammelt alle Reports, updated `status`/`fix_attempts` pro BUG-ID, entscheidet über Re-Spawns für noch offene Bugs.

**Invariant:** Disjunkte Dateien → keine zwei parallelen Fixer schreiben dieselbe Datei gleichzeitig. Anchors schützen bei sequentiellen Edits innerhalb eines Clusters vor Line-Shift.

**Beispiel:** 12 Bugs über 7 Dateien → 7 parallele Fixer-Spawns. Wall-Clock fällt von 12 × T auf ≈ max(T pro Datei).

**Gilt für QA-/Quality-Gate-Fixes:** Skill 6 QA-Persona-Bugs und Skill-5 Quality-Gate-Findings. In `conservative` Autonom-Level wird ebenfalls parallelisiert, aber bei erstem Cluster-Fail gestoppt statt weiterzulaufen.

### QA (nach Quality Gate)

Vier parallele QA-Streams:

| Stream | Wer | Was |
|--------|-----|-----|
| Browser E2E | Lead (Main Agent) | Playwright MCP auf Dev-Server, testet jeden AC im Browser |
| Red Team | `red-team-tester` | Injection, Auth-Bypass, Boundaries, Race Conditions |
| UI Audit | `ui-auditor` | Design System Compliance, Registry Check, Responsive, A11y |
| Persona Code Review Panel | Codex-Plugin oder Claude | 5 Reviewer mit je 20y Erfahrung: Chen (Security), Weber (Principal Eng.), Sharma (Performance), Müller (SRE), Rodriguez (PROJ Retrospective) |

**Fix Loop:** Critical/High Bugs → sofort fixen → re-testen. Medium/Low → User fragen.

**Zusätzliche Outputs aus QA:**
- `## AGENTS.md Candidates` in `7_progress/…progress.md` — projektweite Ein-Zeilen-Regeln aus Personas / Red-Team / Sonar, streng gefiltert (Wiederhol-Risiko, projektweit, ≤ 120 Zeichen). Werden in Skill 7 User-approved in AGENTS.md gemerged (40-Zeilen-Cap).
- `## PROJ Retrospective` in `7_progress/…progress.md` — Elena Rodriguez' Narrative „Was sollte sich für das nächste PROJ ändern?". Skill 7 liest das und füttert TECHNICAL.md sowie den nächsten `architecture`-Durchlauf.

---

## 10. Referenz-Skills

Referenz-Skills sind **keine Prozessschritte** — sie sind Expertise-Module die während der Ausführung konsultiert werden. Sie werden nicht über `/skill-name` aufgerufen, sondern sind in Agent-Definitionen eingebettet oder werden vom Main Agent bei Bedarf gelesen.

### Cross-Cutting (alle Projekte)

| Skill | Konsultiert in | Eingebettet in | Zweck |
|-------|---------------|----------------|-------|
| `systematic-debugging` | Step 5, 6 | Implementer-Agenten (Kurzfassung), `5_executing` | 4-Phasen-Debugging: Root Cause → Pattern Analysis → Hypothesis → Fix. **3-Fix Rule:** Nach 3 gescheiterten Fixes → STOP, an User eskalieren. |
| `verification-before-completion` | Step 5, 6 | Alle 3 Implementer-Agenten (Verification Gate) | Gate Function: RUN → READ → VERIFY → CLAIM. Verhindert "should work"-Claims ohne Evidenz. |

**Wie sie eingebettet sind:**

Die Kernprinzipien sind direkt in die Agent-Definitionen kopiert (nicht als Referenz verlinkt), damit Subagenten sie immer im Context haben:

- **`implementer.md`:** Verification Gate (4 Schritte), Debugging Root Cause First, 5 TDD Anti-Patterns
- **`frontend-implementer.md`:** Verification Gate, Debugging (kompakt), 3 TDD Anti-Patterns
- **`backend-implementer.md`:** Verification Gate, Debugging (kompakt), 3 TDD Anti-Patterns
- **`5_executing`:** "When Something Breaks" Section referenziert `systematic-debugging`; Quality Gate Handling nutzt "Receiving Code Review"-Disziplin (READ → VERIFY → EVALUATE → FIX)

### Tech Stack (projektspezifisch)

| Skill | Konsultiert in | Zweck |
|-------|---------------|-------|
| `tailwind-css` | Step 2b, 3, 5 | Responsive Utilities, Dark Mode, Component Patterns, Class Organisation |
| `nextjs-app-router-patterns` | Step 3, 4, 5 | Server vs. Client Components, Routing, Data Fetching, Caching |

Tech-Stack-Skills werden an Implementer-Agenten **per Prompt übergeben** (nicht eingebettet), wenn der US den entsprechenden Stack berührt.

### Eingebettete Verbesserungen ohne eigenen Skill

Einige Superpowers-Konzepte wurden direkt in bestehende Skills/Agenten eingebaut statt als eigene Skills:

| Konzept | Eingebaut in | Was es tut |
|---------|-------------|------------|
| **Receiving Code Review** | `5_executing` (Quality Gate Handling) | Findings nicht blind implementieren: READ → VERIFY → EVALUATE → FIX. Push-Back bei YAGNI-Verletzungen und False Positives. |
| **Plan Self-Review** | `4_writing-plans` (Step 5) | Nach dem Schreiben: Placeholder Scan, Spec Coverage, Task Decomposition, Dependency Check, No Vague Instructions. |
| **TDD Anti-Patterns** | Alle Implementer-Agenten | Warnt vor: Testing Mock Behavior, Test-only Methods, Mocking without Understanding, Incomplete Mocks. |
| **Scope Decomposition** | `1_brainstorming` | Vor Detailfragen prüfen ob Projekt zu gross → in Sub-Projekte zerlegen. |
| **Concept Self-Review** | `1_brainstorming` | Nach Concept Doc: Placeholder Scan, Consistency, Scope, Ambiguity Check. |
| **User Review Gate** | `1_brainstorming` | Expliziter Halt: User reviewt Concept vor Transition. |

---

## 11. Greenfield, Brownfield, Hybrid

| Aspekt | Greenfield | Hybrid | Brownfield |
|--------|------------|--------|------------|
| **Erkennung** | Kein belastbarer App-Shell, keine wiederverwendbaren Komponenten, keine Tokens, keine realen Screens | Einige Muster existieren, aber wichtige Komponenten/Tokens/Flows fehlen | Bestehende Screens, Komponenten, Tokens und Navigation sind klare Constraints |
| **Step 2a (Frontend Design)** | Empfohlen — definiert Design-Sprache von Grund auf | Leichtgewichtig — nur dokumentierte Gaps füllen | Übersprungen — Design System existiert |
| **Step 2b (UI Mockup)** | Nutzt `design-language.md` als primäre Quelle | Nutzt bestehende Patterns + Gap-Ergänzungen | Nähert Mockups an bestehende Komponenten/Farben/Schriften an |
| **Implementation Handoff** | Definiert neue Tokens und Component Candidates | Trennt Reuse vs. neue Candidates besonders klar | Erzwingt Reuse und markiert Abweichungen |
| **Component Registry** | Leere Registry, wird beim ersten UI-Component gefüllt | `component-scout` ergänzt Registry um fehlende Kandidaten | `component-scout` scannt Codebase, erstellt/aktualisiert Registry |
| **Design System Reference** | Wird durch Step 2a erstellt | Bestehend + Gap-Ergänzung | Bereits in `tailwind.config` / `globals.css` vorhanden |
| **agent.md** | Existiert nicht — wird bei erstem Gotcha erstellt | Kann teilweise existieren → wird gelesen | Kann aus vorheriger Arbeit existieren → wird gelesen |

### Brownfield-Onboarding

Bei einem bestehenden Projekt:
1. Visual Companion erkennt `Project Mode: brownfield` anhand von App-Shell, Komponenten, Tokens und Screens.
2. Frontend Design wird übersprungen, außer der User fordert eine Design-Änderung.
3. UI Mockup erstellt komponentennahe HTML-Annäherungen und schreibt `implementation-handoff.md`.
4. Writing Plans propagiert den Handoff in jede Frontend-/Full-stack-Task.
5. Execution nutzt bestehende React-Komponenten/Tokens vor exakter HTML-Mockup-CSS.

---

## Anhang: Dateistruktur

```
~/.claude/
├── agents/
│   ├── implementer.md
│   ├── frontend-implementer.md
│   ├── backend-implementer.md
│   ├── integration-guard.md
│   ├── code-reviewer-gate.md
│   ├── sonar-scanner-gate.md
│   ├── red-team-tester.md
│   ├── ui-auditor.md
│   └── component-scout.md
├── hooks/
│   ├── context-statusline.js         (statusLine)
│   ├── context-monitor.js            (PostToolUse)
│   ├── prompt-guard.js               (PreToolUse)
│   ├── validate-commit.sh            (PreToolUse)
│   ├── wave-gate-enforcer.js         (PreToolUse)
│   └── component-registry-check.js   (PreToolUse)
├── skills/
│   ├── 0_process-guide/SKILL.md
│   ├── 1_brainstorming/SKILL.md
│   ├── 1b_visual-companion/SKILL.md
│   ├── 2_requirements-engineer/SKILL.md
│   ├── 2a_frontend-design/SKILL.md
│   ├── 2b_ui-mockup/SKILL.md
│   ├── 3_architecture/SKILL.md
│   ├── 4_writing-plans/SKILL.md
│   ├── 5_executing/SKILL.md
│   ├── 6_qa/SKILL.md
│   ├── 7_documentation/SKILL.md
│   ├── systematic-debugging/SKILL.md          (Referenz-Skill)
│   ├── verification-before-completion/SKILL.md (Referenz-Skill)
│   ├── tailwind-css/SKILL.md                   (Referenz-Skill)
│   └── nextjs-app-router-patterns/              (Referenz-Skill)
└── settings.json                   (Hook-Registrierung)
```

### Pro Projekt

```
project/
├── AGENTS.md                       (≤ 40 Zeilen, harte Projekt-weite Regeln — Skill 7 merged approved Candidates)
├── README.md                       (Step 7 Output — ≤ 50 Zeilen, Entry-Point)
├── specs/
│   ├── INDEX.md                    (globaler PROJ-Ueberblick, optional)
│   └── PROJ-<X>-<thema>/           (alle Artefakte einer Initiative)
│       ├── 1_brainstorm/
│       │   └── PROJ-<X>-concept.md              (Step 1 Output)
│       ├── 2_visual-companion/                  (Step 1b Output, UI-Feature)
│       │   ├── layout-exploration.html
│       │   └── layout-decision.md
│       ├── 3_PRDs/                              (Step 2 Output)
│       │   └── PROJ-<X>-PRD-<Y>-<desc>.md       (wachst: QA Results S6 appended)
│       ├── 4_design/                            (Step 2a Output, greenfield/hybrid gaps)
│       │   └── design-language.md
│       ├── 5_mockups/                           (Step 2b Output)
│       │   ├── sitemap.html
│       │   ├── *.html
│       │   └── implementation-handoff.md
│       ├── 6_plan/                              (Step 3 + Step 4 Output)
│       │   ├── PROJ-<X>-architecture.md         (Step 3)
│       │   ├── PROJ-<X>-wave-<N>-plan.md        (Step 4, pro Wave)
│       │   └── wave-gate-config.json            (Step 4, machine-readable Gate)
│       └── 7_progress/                          (Step 5 + 6 Runtime)
│           ├── PROJ-<X>-progress.md             (ein File pro PROJ, trackt alle Waves, AGENTS.md Candidates, PROJ Retrospective)
│           └── PROJ-<X>-autonomous-log.md       (optional, bei autonomous-execution: Policy-Audit)
├── docs/
│   ├── PROJECT.md                  (Step 7 Output — Feature-Katalog, immer aktualisiert)
│   ├── TECHNICAL.md                (Step 7 Output — Cross-cutting Decisions, Data Model, Gotchas)
│   └── components.md               (Component Registry, gepflegt von component-scout)
├── scripts/
│   └── wave-gate.sh                (Wave-Gate-Script, Skill 5)
└── src/
    ├── app/(dev)/components/
    │   └── page.tsx                (Component Showcase auf /dev/components)
    └── features/<name>/
        └── agent.md                (Agent-Notizen von Implementern; Skill 7 harvestet in TECHNICAL.md)
```

---

## 12. Externe Abhängigkeiten (CLI / Plugins / MCPs)

Die Skill Chain orchestriert mehrere externe Tools. Fehlen sie, degradiert die Chain (Fallback-Pfade vorhanden) oder halted.

### CLIs (via `command -v` im Preflight geprüft)

| CLI | Pflicht? | Wo eingesetzt | Install |
|---|---|---|---|
| **`codex`** (OpenAI Codex CLI, ≥ 0.121) | **Optional** (Path A für Persona-Reviews) | 6-Persona-Panel inkl. Ken am PROJ-Ende (Skill 6) — via Companion-Script `node $COMPANION adversarial-review --background`, nicht via Slash-Command | `npm i -g @openai/codex-cli` |
| **`coderabbit`** | Pflicht | Wave-Gate (Skill 5) — `coderabbit review --agent --base-commit $WAVE_BASE`. Fehlt → wave-gate.sh failt hart. | [coderabbit.ai/cli](https://coderabbit.ai) |
| **`agent-browser`** | Empfohlen (wenn `frontend_routes` gesetzt) | Wave-Gate Smoke-Test. Backend-only Waves brauchen es nicht. | (CLI des `agent-browser` Tools) |
| **`jq`** | **Pflicht** | wave-gate.sh, merge-project-settings.sh, Codex-Status-Parsing | `apt install jq` |
| **`sonar-scanner`** | Empfohlen | Quality Gate (Skill 5 Step 9) — SonarCloud Scan. Ohne scanner skipped der sonar-scanner-gate agent. | SonarSource Download |
| **Node.js** (≥ 18) | **Pflicht** | Codex-Companion-Script, Hooks (wave-gate-enforcer.js, component-registry-check.js) | system |
| **Git** (≥ 2.30) | **Pflicht** | Überall — Tags, rev-parse, log, diff | system |

### Claude-Plugins (`~/.claude/plugins/`)

| Plugin | Pflicht? | Wo eingesetzt |
|---|---|---|
| **`codex@openai-codex`** | **Optional** (Path A) | Liefert Companion-Script (`codex-companion.mjs`) für adversarial-review. Pfad via Glob: `ls ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs \| sort -V \| tail -1`. **Slash-Commands `/codex:*` sind `disable-model-invocation: true`** und können NICHT aus Skills aufgerufen werden — daher immer direkt das Companion-Script via Bash. |
| **`vercel-plugin`** | Optional | Bei Vercel-Deployments (Skill 5 / nach QA). |

Fehlt Codex-Plugin → Skill 5 + 6 fallen automatisch auf Path B (Claude `general-purpose` Subagent mit Persona-Prompt) zurück. Funktional äquivalent, nur langsamer.

### MCPs (preflight in Skill 5 FIRST ACTION)

| MCP | Pflicht? | Wann benötigt |
|---|---|---|
| **Supabase MCP** (`mcp__claude_ai_Supabase__*`) | Bedingt | Wenn `@supabase/*` in package.json ODER `supabase/` Folder existiert. Apply_migration, execute_sql, deploy_edge_function. |
| **Playwright MCP** (`browser_navigate`, `browser_snapshot`, …) | Bedingt | Wenn eine Wave in `wave-gate-config.json` nicht-leere `frontend_routes` hat. Skill 6 QA-Stream 1 baut darauf auf. |

Fehlende MCP beim Preflight-Check → **STOP**, Skill 5 halted mit User-Hinweis "reconnect via Codex MCP configuration".

### Permissions / Launch-Flag

| | |
|---|---|
| **`--dangerously-skip-permissions`** (CLI-Flag) | **Empfohlen** für Skills 5/6/7. Einziger garantierter Zero-Prompt-Pfad. `claude --dangerously-skip-permissions` beim Start. Nur in Disposable-Env (Dev-VM, keine Prod-Creds, protected branches). |
| **`.claude/settings.json` + `merge-project-settings.sh`** | Fallback — `defaultMode: bypassPermissions` plus 209-Entry Allowlist + 31-Entry Denylist. Deny bleibt bei Path B auch aktiv. |

### Projekt-lokale Scripts (aus `~/.codex/skills/5_executing/scripts/`)

| Script | Zweck |
|---|---|
| **`wave-gate.sh`** | Pro-Wave Hard-Gate (ACs + Build + CodeRabbit + Smoke) mit Base-SHA-Resolution (env > Tag; sonst harter Fail) + Auto-Tag der nächsten Wave |
| **`proj-readiness-check.sh`** | Nach Skill 7: prüft ob nächster PROJ fully planned (architecture + wave plans + PRD-Coverage) → auto-continue ODER stop |
| **`merge-project-settings.sh`** | Idempotent: mergt Template in `.claude/settings.json`, setzt `defaultMode: bypassPermissions` beim ersten Run |

### Projekt-lokale Config-Files

| File | Zweck | Template |
|---|---|---|
| **`.coderabbit.yaml`** | Per-Projekt CodeRabbit-Config (profile: chill, path_filters, path_instructions) | `~/.codex/skills/5_executing/references/coderabbit-template.yaml` |
| **`.claude/settings.json`** | Permissions (Allow/Deny/defaultMode) | `~/.codex/skills/5_executing/references/project-settings-template.json` |
| **`specs/PROJ-<X>-<thema>/6_plan/wave-gate-config.json`** | build_cmd, timeouts, advisory_severities, AC-Commands + frontend_routes pro Wave | Skill 4 generiert |
