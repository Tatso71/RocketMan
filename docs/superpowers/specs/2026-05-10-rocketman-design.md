# RocketMan Design Spec

Date: 2026-05-10
Project: RocketMan
Branch: Aurora
Status: Draft approved in brainstorming, written for review

## Concept Summary

RocketMan is a 2D side-scrolling exploratory platformer set on an unknown planet. The protagonist is left alone in an underground base after the death of their grandfather. From that point, the player must understand how the base works, discover that the outside world is full of strange animal species, and rebuild the ancestral rocket before the planet collapses.

The game is not action-forward or frantic. Its identity comes from exploration, environmental understanding, puzzle solving, creature study, and scientific progression. The tone is adventure-scientific, with emotional weight from grief and inheritance, but without constant survival pressure.

## Design Goals

The game should:

- Deliver a strong mystery through the base, the grandfather, and the planet.
- Support modular expansion through a base hub plus external regions.
- Make animals central to exploration rather than simple companions or combat units.
- Use guided crafting and discovery instead of opaque experimentation.
- Reward every expedition with knowledge, access, or progress, even when the player does not complete an immediate objective.
- Maintain a calm, thoughtful pace built around curiosity and preparation.

The game should avoid:

- Heavy management simulation in the base.
- Combat as a primary source of challenge.
- Hard fail states that punish exploration.
- Time pressure that makes players rush through discovery.

## Recommended Product Direction

Three possible approaches were considered:

1. Story-first with creature systems as support
2. Exploration-first with animals as the core driver
3. Base mystery plus expedition modules

The selected direction is Approach 3 with a strong dose of Approach 2.

That means:

- The underground base is the narrative and systemic center of the game.
- The outer world is built as modular regions that can expand over time.
- Animals are a core exploration system, not a side mechanic.
- The rocket reconstruction is the macro-objective that ties all progression together.

## Player Fantasy

The player fantasy is:

"I inherited a buried machine-world and a scientific mystery. I learn how this place works, build trust with alien animals, uncover what my family was doing here, and escape an unstable planet through knowledge rather than force."

This fantasy depends on three feelings:

- Curiosity about how systems and ecosystems work
- Emotional attachment to the grandfather's legacy
- Satisfaction from turning understanding into access and progress

## Core Gameplay Loop

The core loop is:

1. Explore the base and unlock terminals, rooms, archives, and hatch routes.
2. Identify a clear need such as a rocket subsystem requirement, a missing material, or a blocked system.
3. Prepare an expedition by choosing tools, inventory, and up to three trained animals.
4. Explore the external world, observe species, collect materials, scan clues, and uncover shortcuts.
5. Return to the base with samples, data, new species knowledge, and narrative discoveries.
6. Use those findings to unlock new base functions, process materials, and advance rocket reconstruction.

The guiding rule is that expeditions do not truly fail. A trip may be incomplete, but it should still produce at least one meaningful gain:

- new knowledge
- a scanned species
- a new route
- a new material entry
- a new clue about the base or planet
- a new possibility for a future expedition

## World Structure

### The Base

The base is a single large hub level. It is not a management simulation. It is a puzzle-rich scientific habitat that the player learns to read over time.

Its main purposes are:

- Tell the story of the protagonist, the grandfather, and the ancestors
- Act as the interpretation layer for external discoveries
- Gate access to new regions, systems, and rocket functions

Suggested sectors:

- Living quarters and family memory spaces
- Materials laboratory
- Species archive and scanning center
- Rocket workshop
- Energy and life-support systems
- Tube and hatch network connecting to the planet

The player should gradually reinterpret the base as they learn more, so old spaces gain new meaning later in the game.

### The Exterior World

The exterior world is organized as large modular regions accessed from mysterious tubes or hatches in the base. Each region should feel distinct enough to be built as an independent production module.

Internally, each region uses a metroidvania structure:

- blocked paths on first visit
- return visits with new abilities
- permanent shortcuts
- layered traversal and puzzle interactions

Each external region should include:

- one strong environmental identity
- three to five major species
- two to three exclusive materials
- one ecological or technological mystery
- one concrete contribution to rocket reconstruction
- one connection to ancestral or grandfather history

### Progression Logic

The world progression runs like this:

base -> expedition -> discovery -> return -> new base understanding -> deeper expedition

The base unlocks new routes and research functions. External regions provide:

- rocket materials
- species knowledge
- trainable animals
- ecological clues
- new ways to reactivate the base

## Player Character

The protagonist is strongly characterized rather than silent or lightly sketched.

This supports:

- a visible emotional arc after the grandfather's death
- stronger reactions to discoveries in the base
- a more personal relationship with the planet
- narrative tension around leaving versus understanding the world

The protagonist should feel intelligent, curious, and emotionally affected by inheritance and isolation, but not melodramatic.

## Narrative Structure

The narrative rests on three intertwined threads:

- grief after the grandfather's death
- scientific understanding of the base and planet
- the long-term push to rebuild and launch the rocket

The grandfather remains present through:

- personal rooms and unfinished tools
- logs, recordings, and notes
- contradictory evidence about what he knew
- traces of care, secrecy, and preparation

The narrative should evolve in stages:

- At first, the grandfather is a missing guide.
- Later, he becomes a mystery with hidden knowledge.
- Eventually, he becomes part of the truth about the planet and the escape plan.

## Time Pressure

The collapsing planet is a narrative pressure, not a real-time punishment system.

This means:

- the player should feel urgency in the story
- the environment may show signs of instability over time
- major discoveries can escalate the perceived danger
- exploration remains calm and deliberate

Time should not create constant countdown anxiety. It should provide dramatic context and endgame momentum.

## Animals

Animals are one of the deepest systems in the game and a central source of progression.

They are not mainly combat units. They are exploration partners.

Each species should include:

- a clear environmental role
- a behavior profile
- a training condition or bonding requirement
- at least one synergy with another species, material, or biome

Possible environmental functions include:

- illuminating dark areas
- stabilizing fragile terrain
- detecting hidden organisms or currents
- neutralizing toxins, spores, cold, or electrical hazards
- carrying fragile resources
- activating organic or geological mechanisms

### Expedition Team

Before each expedition, the player selects:

- protagonist equipment
- active tools
- up to three trained animals

This choice is strategic rather than power-based. The player should choose animals that suit a region, mystery, or environmental barrier.

### Animal Progression

Because the animal system is meant to be deep, each animal can carry several layers:

- species traits
- individual traits
- trust or bond level
- unlockable abilities
- biome preferences
- compatibility with other species
- responses to foods or materials

This creates three different progression axes:

- discovery of new species
- training and bonding
- team composition and synergy design

## Inventory and Materials

The inventory system should remain readable and low-friction.

Recommended inventory categories:

- raw materials
- processed components
- data and schematics
- key items and tools

Animals are part of expedition loadout and should not occupy ordinary inventory space.

### Crafting Model

Crafting is guided through discovered schemas, terminals, and workshop procedures. It should not rely on blind trial and error.

The recommended flow is:

collection -> laboratory analysis -> schema unlock -> processing -> component creation

Materials should serve both practical and narrative functions. They are not only crafting inputs. They also teach the player about the planet's logic and composition.

## Rocket Reconstruction

The rocket is the macro-objective that binds the entire game together.

It should be rebuilt across major subsystems rather than treated as a final recipe dump.

Suggested subsystems:

- energy and ignition
- hull and integrity
- navigation
- life support
- fuel or fuel-equivalent biological-technological system

Each subsystem should require:

- specific materials
- one or more discovered schematics
- at least one meaningful expedition
- interaction with planetary species or ecology
- reactivation of a related base sector

This ensures rocket progress is woven through the entire experience.

## Puzzle Design

Puzzle types should be:

- environmental puzzles
- systemic puzzles combining tools, animals, and materials
- infrastructure puzzles inside the base

Puzzles should always emerge from world logic rather than abstract puzzle-room design.

Examples:

- a species reacts to sound or frequency
- a material changes state under heat, cold, or current
- a distant system in the base must be realigned to open a route
- an animal reveals the function of what first looked like scenery

The player should frequently feel "I understand this system now" rather than "I guessed the designer's trick."

## Combat and Failure Model

Combat exists only lightly or situationally. It is not a primary pillar.

The main sources of challenge are:

- traversal
- environmental conditions
- puzzle solving
- expedition planning
- understanding creature behavior

Expeditions should not have traditional hard failure in most cases. A difficult run can still return useful knowledge or access.

This design supports a more exploratory and scientific tone.

## Overall Pacing

The game rhythm should alternate between:

1. quiet reflection and investigation in the base
2. expedition preparation
3. attentive exploration in the wild
4. discovery or insight
5. return and reinterpretation

The pace should feel calm, thoughtful, and rewarding. The player should often come away feeling smarter, more prepared, or more connected to the planet.

## Suggested Game Structure

### Act 1

- The grandfather dies.
- The player survives the first isolation phase.
- The base is only partially understandable.
- The first hatch opens and the player reaches the outside.

### Act 2

- New biomes and animal species deepen the exploration systems.
- The player begins to understand the ancestors' technological footprint.
- The base reveals more complex functions.
- The rocket begins to take shape through recovered subsystems.

### Act 3

- The planet's instability becomes more visible and concrete.
- The final truths about the grandfather and the planet are uncovered.
- The player completes the critical rocket systems.
- The final departure sequence becomes possible.

### Ending

The climax should be more emotional and revelatory than combat-driven. The ending should pay off the relationship between inheritance, knowledge, and escape.

## Modularity and Expansion Strategy

The game's structure is intentionally modular.

The base acts as a permanent central hub. External regions act as expandable content modules with clean production boundaries. This supports:

- incremental development
- easier collaboration
- future expansion of regions, species, and materials
- controlled scope for early milestones

This structure is one of the game's strongest production advantages and should be preserved in implementation planning.

## System Boundaries for Implementation Planning

The first implementation plan should likely break the game into these major systems:

- player movement and interaction
- base hub structure
- external region framework
- animal data model and expedition team system
- inventory and materials pipeline
- crafting and schematic unlocks
- puzzle interaction framework
- rocket reconstruction progression
- dialogue, logs, and narrative delivery

These systems should stay modular enough that future regions, species, and story beats can be added without rewriting the core.

## Testing and Validation Goals

During implementation, the project should validate:

- the core loop is understandable without long tutorial walls
- the base feels meaningful rather than just a menu-space
- animal choice changes how expeditions play
- every expedition yields some valuable outcome
- progression gates feel logical, not arbitrary
- the rocket objective stays present across the game

Early prototyping should focus on proving the loop before building large content volume.

## Scope Recommendation

For a first playable milestone, keep scope narrow:

- one small but rich base sector
- one external biome
- three to five animal species
- a simple inventory and schema flow
- one early rocket subsystem goal
- one full return loop from base to biome and back

If that slice feels good, the broader game structure can scale from it confidently.

## Final Direction

RocketMan should be built as a calm but purposeful exploratory platformer where scientific discovery, creature partnership, and inherited mystery drive progress. The strongest version of the game is not a combat-heavy survival experience, but a modular expedition game anchored by a memorable underground base and a planet that becomes legible through study.
