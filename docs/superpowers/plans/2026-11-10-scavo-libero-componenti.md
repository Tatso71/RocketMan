# Scavo libero e componenti Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Rendere lo scavo libero dal carico comune e sostituire i cubi monouso con componenti prodotti in laboratorio e montati sul posto.

**Architecture:** Conservare il prototipo Godot e gli stati di struttura planned/building/active. Un catalogo runtime unico definisce minerali, componenti, lotti e costi di montaggio; inventario, produzione, progetti e tutorial usano gli stessi ID. Il terreno cambia presentazione, non collisioni o celle.

**Tech Stack:** Godot 4.6.3, GDScript, JSON, GdUnit4, test SceneTree headless/native, validatore Node esistente. Nessuna nuova dipendenza.

**Spec:** `docs/superpowers/specs/2026-11-10-scavo-libero-componenti-design.md` (approvata).

## Global Constraints

- Branch esistente `codex/scavo-libero`; niente nuovi worktree e niente commit, push, PR o merge senza richiesta.
- 1 cella = 1 metro = 40 pixel. Le collisioni e la simulazione delle falde restano metriche.
- Terra, pietra e resa della roccia compatta non entrano nel carico o nelle ricette runtime.
- Due soli componenti: `structural_component`, `electronic_component`; quattro pezzi dello stesso tipo per unita' di carico, arrotondando per eccesso.
- Primo laboratorio: 4 strutturali + 2 elettronici; produzione iniziale garantita da 8 ferro + 3 rame + 1 cristallo.
- Stessa economia e interazioni nelle varianti Umano e Robbie. Cargo fisico di Robbie e depositi locali, mai scorte remote.
- Salvataggi nuovi separati dai vecchi, inclusa la separazione `_robbie`. Nessuna migrazione silenziosa.
- Scale gratuite e immediate, scale interne protette; jetpack pieno dopo un vero atterraggio, indipendente dalla manutenzione di Robbie.
- Usare `apply_patch`, preservare modifiche esterne e aggiornare i testi e i test quando cambia il contratto.

## Review Focus

1. A carico pieno o con Robbie in consegna il giocatore deve continuare a scavare terreno; un minerale non raccolto deve restare recuperabile (Task 2).
2. Stack parziali in inventari quasi pieni non devono perdere/duplicare pezzi o superare la capienza durante trasferimenti e pagamenti (Task 1).
3. Una produzione pagata con banco/deposito pieno o salvata al limite di completamento non deve perdere o duplicare l'uscita (Task 3).
4. Un progetto con componenti sufficienti, ma geometria cambiata o Robbie non accessibile, non deve attivarsi o addebitare da remoto (Task 4).
5. Tenere premuta la spinta vicino al pavimento o aprire un menu non deve fornire carica infinita in volo; le scale non sono un atterraggio (Task 5).

## Verifica di partenza

Gia' eseguita: 145 test unitari in 21 suite, zero errori/fallimenti. Log: `reports/components-design-baseline-unit.log`. Nessun codice di gioco e' ancora modificato.

Nei comandi seguenti `$godot` indica `(Get-Command Godot_v4.6.3-stable_win64_console.exe).Source`. Per i test UI/render usare `--rendering-method gl_compatibility` senza `--headless` e aggiungere `-- --capture`.

## File e responsabilita'

- Nuovi `design/v1/prototype_components.json` e `scripts/data/component_catalog.gd`: bilanciamento runtime e validazione di ricette/lotti/costi.
- `field_cargo.gd`: quantita', stack, capienza, pagamenti e trasferimenti atomici; non si occupa di produzione.
- `dig_site.gd`, `ocra_geology.gd`, `digital_tool_catalog.gd`: materiali e fonti scavabili, separati dalla resa grafica.
- `fabrication_state.gd`: lavorazioni e uscite pronte per postazione, snapshot/restore; `outpost_controller.gd` collega stato, ingredienti, energia e mondo.
- `fabrication_ui.gd`: produzione a lotti; nuovo `assembly_ui.gd`: scelta struttura, sagoma e progetto in attesa. Niente pannello permanente.
- `outpost_buildings.gd`: ingombri e stati delle strutture, senza costi duplicati nel codice.
- `expedition_gear.gd` e `rocket_explorer.gd`: atterraggio/jetpack; il resto dei consumi energetici resta distinto.
- Nuovo `scripts/ui/terrain_renderer.gd`: helper di disegno usato da `_draw_terrain`, con la stessa sequenza di rendering del mondo esistente.
- Tutorial, testi, UI inventario e salvataggi completano il nuovo percorso, senza cambiare le scene storiche base/bioma.

### Task 1: Catalogo runtime e inventario compatto

**Files:** creare `design/v1/prototype_components.json`, `scripts/data/component_catalog.gd`, `tests/unit/test_component_catalog.gd`; modificare `scripts/systems/field_cargo.gd`, `tests/unit/test_field_cargo.gd`.

**Interfaces:** `ComponentCatalog.load_data() -> Dictionary`, `validate(data: Variant) -> Dictionary`, `recipe(id: String) -> Dictionary`, `assembly_cost(id: String) -> Dictionary`; `Cargo.units_for(id: String, amount: int) -> int`. Conservare `used`, `collectible`, `collect`, `available`, `can_pay`, `pay`, `withdraw`, `deposit`, `snapshot`, `restore` con le firme esistenti.

- [x] Scrivere test per E: 3 rame + 1 cristallo -> 2 elettronici; S: 4 ferro -> 2 strutturali; costi delle sette strutture identici alla specifica. Rifiutare ID sconosciuti, quantita' negative/frazionarie/non finite e ingredienti terra/pietra.
- [x] Aggiungere assert di capienza: 1/4/5 componenti consumano rispettivamente 1/1/2 unita'; pagare un pezzo da uno stack di cinque libera una unita'. Un pagamento insufficiente lascia ogni sorgente invariata. Provare trasferimenti parziali con uno stack gia' aperto e roundtrip JSON a carico pieno.
- [x] Eseguire `$godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/test_component_catalog.gd -a res://tests/unit/test_field_cargo.gd --ignoreHeadlessMode` e verificare i fallimenti del nuovo contratto.
- [x] Implementare catalogo e matematica degli stack: ferro, silice e cobalto con nomi/colori; niente terra/pietra tra gli oggetti della nuova economia. Calcolare la capienza dalle quantita' reali, non moltiplicando un peso intero per ogni componente. La validazione accetta fino a quattro volte la capienza quando le quantita' sono componenti.
- [x] Rieseguire i test mirati fino a zero errori/fallimenti; aggiornare solo le vecchie aspettative di costo/capienza effettivamente superate.

### Task 2: Minerali, resa e scavo senza carico obbligatorio

**Files:** modificare `scripts/systems/dig_site.gd`, `scripts/data/ocra_geology.gd`, `scripts/data/digital_tool_catalog.gd`, `scripts/prototype/rocket_home.gd`, `scripts/prototype/expedition_gear.gd`, `tests/unit/test_dig_site.gd`, `tests/unit/test_ocra_geology.gd`; creare `tests/integration/free_digging_smoke.gd`.

**Interfaces:** aggiungere `DigSite.resource_yield(kind: String) -> String` (vuoto per soil/stone/bedrock); conservare `mine`, `material`, `snapshot`, `restore`. `Gear.drops` continua a rappresentare i minerali recuperabili a terra.

- [x] Scrivere test che scavano almeno 30 celle comuni con carico pieno e Robbie assente/in consegna: terreno rimosso e carico invariato. Minerale non raccoglibile lasciato in `drops`, recuperabile esattamente una volta anche dopo salvataggio. Ripetere con esplosione.
- [x] Eseguire il test e verificare che il vincolo di capienza attuale e la resa comune lo facciano fallire.
- [x] Togliere il blocco di capienza da `target_blocker` per lo scavo; dopo `mine` accreditare solo una resa non vuota, lasciandola a terra se `collect` fallisce. Applicare la stessa funzione alle bombe. Conservare tutti i vincoli di utensile, portata, pareti, supporti e indistruttibilita'.
- [x] Aggiungere giacimenti reali di ferro/silice/cobalto e cristallo iniziale su Ocra, senza scavi prefabbricati e senza sovrapporre falde/ancore. Pulse scava ferro/silice/cristallo, Risonatore aggiunge cobalto, Plasma mantiene la roccia compatta. Garantire i 12 minerali del primo laboratorio in zone raggiungibili dal carico iniziale.
- [x] Eseguire unitari mirati e `$godot --headless --fixed-fps 60 --path . -s res://tests/integration/free_digging_smoke.gd`; verificare energia, pericoli e semi invariati e nessun messaggio di carico da terra/pietra.

### Task 3: Produzione a lotti e buffer locale

**Files:** modificare `scripts/systems/fabrication_state.gd`, `scripts/prototype/outpost_controller.gd`, `scripts/ui/fabrication_ui.gd`, `scripts/data/industry_catalog.gd`, `design/v1/prototype_industry.json`, `tests/unit/test_fabrication_state.gd`; creare `tests/integration/component_production_smoke.gd`.

**Interfaces:** `Outpost.fabricate_components(recipe_id: String, batches: int = 1) -> bool`, `fabrication_definition(recipe_id: String) -> Dictionary`, `collect_fabrication_output() -> int`; riusare `advance_fabrication(delta: float)` e le identita' di postazione esistenti. `FabricationState` salva lavori e buffer di uscita associati alla postazione.

- [x] Scrivere test: tre lotti elettronici costano 9 rame + 3 cristalli e producono sei pezzi, un unico addebito; livello I 2 s/lotto e 0,01 kWh/lotto. Validare lotti interi 1..20, rifiutare ordini su banco gia' occupato e verificare pausa senza energia.
- [x] Testare snapshot a meta' lotto e al completamento, deposito/carico pieni, uscita ritirata parzialmente, officina danneggiata e trasferimento delle sole lavorazioni di bordo durante il viaggio. Eseguire e osservare i fallimenti.
- [x] Sostituire i nuovi ordini di cubi con lotti di componenti; pagare atomicamente ingredienti/energia all'avvio. Conservare le uscite complete finche' possono essere ritirate, senza cancellare lavori pagati chiudendo il menu. Bombe: ricetta separata da 1 S + 1 E, 2 s e 0,01 kWh, limite munizioni quattro.
- [x] Modificare la tabella del banco: nome, resa, selettore lotti, tempo/costi totali, risorse rosse/verdi e Crea disabilitato quando necessario; un comando ritira l'uscita pronta. Livelli di laboratorio conservano il moltiplicatore di velocita' esistente.
- [x] Conservare la fusione del rame e cambiare il vetro da pietra a silice. Dopo il primo laboratorio aggiungere alternative: 2 lingotti + 1 vetro -> 4 E; 2 ferro + 1 cobalto -> 4 S. Eseguire unitari e `component_production_smoke.gd`: nessuna dipendenza da industria per i lotti base.

### Task 4: Sagome, progetti in attesa e montaggio

**Files:** creare `scripts/ui/assembly_ui.gd`, `tests/integration/component_assembly_smoke.gd`; modificare `scripts/prototype/outpost_controller.gd`, `scripts/systems/outpost_buildings.gd`, `scripts/ui/workstation_menu.gd`, `scripts/ui/physical_cube_view.gd`, `tests/unit/test_outpost_buildings.gd`.

**Interfaces:** conservare `placement_origin`, `placement_blocker`, `place`, `funding_blocker`, `fund_site`; aggiungere `cancel_plan(building: Dictionary) -> bool`. `place_blueprint(cell: Vector2i) -> bool` crea il progetto, non attiva un cubo. `site_cost` legge il catalogo dei componenti e `fund_site` non consulta depositi remoti.

- [x] Scrivere test per progetto valido senza componenti: stato planned, nessun costo o servizio. Finanziarlo con 4 S + 2 E nel carico di Robbie; addebito unico, stato building, attivo solo a fine tempo. Ricaricare a meta' montaggio e cancellare gratis solo un progetto non finanziato.
- [x] Testare componenti sufficienti ma Robbie lontano/in consegna, appoggio scavato dopo la pianificazione, roccia nella sagoma, parete fra giocatore e progetto, bomba sovrapposta e pericolo sopraggiunto. Nessun addebito o attivazione illegittima. Eseguire e verificare i fallimenti.
- [x] Riattivare il menu contestuale di montaggio nello spazio libero, separato dal banco. Sagoma solo dopo la selezione, motivazione rossa per ingombro non valido; progetto in attesa distinto visivamente. Click valido monta se finanziabile oppure lascia il progetto in attesa, mai gratis. Tasto destro sul progetto offre Monta/Annulla e conteggi disponibili/richiesti.
- [x] Conservare stati, barre, tempi, consumi, sblocchi del primo laboratorio, supporti e reti. Eliminare dal nuovo percorso pickup/drop/attivazione dei cubi e la priorita' di Spazio sui cubi: torna un normale comando di salto/spinta. Il renderer delle costruzioni disegna progetti e progressi senza generare oggetti trasportabili.
- [x] Unificare costi di upgrade/riparazioni in componenti e rimuovere ogni costo runtime terra/pietra. Condotti: 1 S per segmento acqua/gas, 1 E per cavo; restano istantanei. Eseguire i test del task e di industria, energia e danni alle installazioni.

### Task 5: Atterraggio del jetpack e scale gratuite

**Files:** modificare `scripts/prototype/expedition_gear.gd`, `scripts/player/rocket_explorer.gd`, `scripts/prototype/rocket_home.gd`, `scripts/systems/outpost_buildings.gd`; creare `tests/integration/ground_jetpack_smoke.gd`; aggiornare `tests/integration/light_and_ammo_smoke.gd`, `tests/integration/equipment_smoke.gd`, `tests/integration/hatch_smoke.gd`.

**Interfaces:** `Gear.observe_ground_contact(grounded: bool, wet: bool, climbing: bool) -> void`, `jetpack_duration_seconds() -> float`, `jetpack_thrust_speed() -> float`; chiamare l'osservazione dopo `move_and_slide`. Durata base 5 s, velocita' verticale base 180 px/s e accelerazione base 700 px/s2, separabili per futuri upgrade.

- [x] Scrivere test per carica zero in aria, 100 dopo vero atterraggio su terreno/pavimento nave, nessuna ricarica su scala, in acqua o solo vicino al suolo. Tenere premuto Spazio durante decollo e menu; consumare regolarmente carica in volo. Conservare la manutenzione a pagamento di Robbie.
- [x] Scrivere test di posa/rimozione ripetuta scale con inventario vuoto: materiali ed energia invariati; pareti/fuori portata e scale interne restano protetti. Eseguire i test prima della modifica e verificare i fallimenti.
- [x] Rimuovere la ricarica del solo jetpack dai laboratori, introdurre rilevazione del contatto di atterraggio ed evitare il refill continuo nel frame di decollo. Parametrizzare durata e spinta senza nuova schermata di acquisto.
- [x] Eliminare il pagamento della scala in tutti gli ingressi, inclusi menu/costi/esempi tutorial; smontaggio senza rimborso. Conservare geometria botola e navigazione di Robbie.
- [x] Eseguire `ground_jetpack_smoke.gd`, `hatch_smoke.gd`, `equipment_smoke.gd`, `light_and_ammo_smoke.gd` e controllare i log per script/parse error, non solo exit code.

### Task 6: Terreno continuo e irregolare

**Files:** creare `scripts/ui/terrain_renderer.gd`, `tests/unit/test_terrain_renderer.gd`, `tests/integration/organic_terrain_smoke.gd`; modificare `scripts/prototype/rocket_home.gd`.

**Interfaces:** `TerrainRenderer.draw(world: Node2D) -> void`, `facets_for(cell: Vector2i, seed: int) -> Array`; `_draw_terrain` delega il disegno ma resta nella stessa sequenza dietro nave/personaggi. Solo il renderer conosce facce/fratture decorative.

- [x] Testare determinismo dei vertici per cella/seme e smussi confinati nel terreno, nessuna modifica a materiali, collisioni o celle rimosse. Il test nativo deve registrare l'attuale regolarita' come baseline e confrontare lo stesso scavo dopo il renderer.
- [x] Implementare masse a tinta continua, facce e venature non ripetute quadrato per quadrato, dettaglio ai soli contorni esposti; mantenere bersaglio esatto e reticolo completo solo con G. Usare seme/coordinate, non tempo o casualita' per frame.
- [x] Eseguire unitari e `organic_terrain_smoke.gd`; acquisire terreno superficiale, stanza scavata e profondita' illuminata a 720p/1080p. Controllare pixel non neri nelle zone illuminate, bordi senza buchi e fluidi leggibili.
- [x] Ispezionare le immagini native: niente apparente roccia nel passaggio, tremolio allo zoom o sovrapposizione della grafica a nave/UI. Ripetere mining e bombe per aggiornamento immediato del contorno.

### Task 7: Tutorial, testi, UI e salvataggi isolati

**Files:** modificare `scripts/core/save_manager.gd`, `scripts/data/ocra_catalog.gd`, `scripts/systems/ocra_tutorial.gd`, `scripts/systems/drone_guide_state.gd`, `scripts/ui/drone_guide.gd`, `scripts/ui/ocra_tutorial_ui.gd`, `scripts/ui/field_inventory_ui.gd`, `scripts/systems/ship_state.gd`, `design/v1/progression.json`, `design/v1/robbie_texts.json`, `design/v1/rules.json`, `docs/technical/robbie-tutorial-authoring.md`, `docs/design/README.md`, `README.md`; creare `tests/integration/component_onboarding_smoke.gd`.

**Interfaces:** salvare in `campaign_components_v1.json` e `rocket_home_components_v1.json`, riusando `variant_path` per Robbie. I payload includono `economy_version: 2` e rifiutano un'economia diversa prima di mutare lo stato. Il catalogo tutorial continua a leggere i compiti da `progression.json`; ricette runtime vengono invece da ComponentCatalog.

- [x] Scrivere test che preservano byte per byte i vecchi save, isolano Umano/Robbie, salvano lavori/buffer/progetti/carico e rifiutano payload invalidi senza mutazione parziale. Usare sempre percorsi di test in reports, mai file user reali.
- [x] Adeguare gli obiettivi ai fatti di raccolta minerali, produzione S/E, ritiro, spazio 4 x 3, progetto e laboratorio attivo; testare azioni anticipate e aiuti muti. Nessun obiettivo da terra/pietra o pickup di un cubo. Eseguire e verificare i fallimenti.
- [x] Collegare snapshot/restore e trasporto fra pianeti al nuovo modello, separando lavorazioni di bordo e locali. Mantenere semi, danni, falde, guide globali e varianti senza azzeramenti.
- [x] Aggiornare catalogo testi, etichette e finestra inventario: minerali e componenti con capacita' corretta, ricette leggibili, nessun Prepara laboratorio a pietre o consiglio Ricarica jetpack in laboratorio. Conservare editing nel text lab e gli override Robbie.
- [x] Percorrere una nuova Ocra reale con entrambi i protagonisti, senza tunnel fixture: raccogliere 8 Fe/3 Cu/1 cristallo, produrre/caricare 4 S/2 E, scavare, pianificare, montare e sbloccare i dispositivi. Eseguire il test e acquisire UI/Robbie a 720p/1080p.

### Task 8: Regressioni e revisione del branch

**Files:** aggiornare le aspettative superate nei test unitari e nei 20 smoke esistenti, in particolare `physical_fabrication_smoke.gd`, `creator_cube_smoke.gd`, `utility_cubes_smoke.gd`, `ocra_onboarding_smoke.gd`, `robbie_tutorial_smoke.gd`, `inventory_guide_smoke.gd`, `industry_smoke.gd`, `robbie_protagonist_smoke.gd`. Riconvertire i test dei cubi a produzione/montaggio preservando le verifiche di pagamento, progresso, pericoli e ripristino.

- [x] Eseguire tutta la suite: `$godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/ --ignoreHeadlessMode`. Richiesti zero errori/fallimenti/orfani.
- [x] Eseguire tutti gli smoke esistenti e nuovi con `--headless --fixed-fps 60`, un log per test. Verificare marker di successo e assenza di `SCRIPT ERROR`, `Parse Error`, `FAIL:`. Non lasciare sessioni di test in esecuzione.
- [x] Eseguire `node tools/design/validate.mjs`, controllare `git diff --check` e il diff completo. Non confondere l'economia futura dei cataloghi completi con la nuova implementazione runtime.
- [x] Far controllare l'intero diff a un revisore indipendente prima di dichiarare il prototipo pronto; correggere le regressioni e rieseguire le verifiche pertinenti.
- [x] Documentare comandi e limiti, avviare il gioco completo con il nuovo slot e consegnare le immagini native piu' significative. Nessun commit/push/merge. Il piano e la specifica restano modifiche locali insieme al codice.

## Autorevisione del piano

- Spec coperta: economia/componenti (1,3,4), scavo/minerali (2), jetpack/scale (5), grafica (6), tutorial/save (7), conservazione delle altre funzioni (8).
- Le interfacce consumate dai task successivi sono definite nei task proprietari. Costi, carico e ricette non vengono duplicati nella UI.
- I cinque casi di Review Focus hanno test nel task indicato.
- I task 5 e 6 sono indipendenti dal catalogo, ma toccano file condivisi con l'integrazione: preferire implementazione sequenziale per limitare conflitti.

## Modalita' proposta

Esecuzione nativa approvata dal giocatore: task per task con test e una revisione indipendente finale. Le interfacce di inventario, produzione, montaggio e tutorial sono strettamente collegate; un solo implementatore riduce la coordinazione. Registro di esecuzione locale in `reports/scavo-libero-progress.md`.
