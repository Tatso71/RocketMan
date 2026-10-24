# RocketMan Specifica di contenuti e sistemi

Versione 1.0 del 24 ottobre 2026. Destinatario: AI incaricata di implementare il gioco. I cataloghi definiscono il progetto completo; non attestano che le funzionalità siano già presenti nel runtime. Le quantità sono valori iniziali di bilanciamento.

## Ordine di lettura per l AI

1. Leggere [manifest.json](../../design/v1/manifest.json) e [contratto di implementazione](ai-implementation-contract.md).
2. Caricare [rules.json](../../design/v1/rules.json): unità, stato iniziale, cubi, logistica, cura, livelli, caverne, creature e viaggio.
3. Caricare i cataloghi richiesti dalla feature. Risolvere i riferimenti per ID; non ricostruire regole dai nomi visibili.
4. Seguire `implementation.feature_order` in [implementation.json](../../design/v1/implementation.json), preservando le funzionalità esistenti.
5. Dopo una modifica eseguire generatore e validatore. Non sostituire i dati di progetto con i riepiloghi generati.

```powershell
node tools/design/build.mjs
node tools/design/validate.mjs
```

## Decisioni stabilite con il giocatore

| Sistema | Decisione |
| --- | --- |
| Universo | 12 pianeti persistenti, con difficoltà progressiva e rami che si incontrano |
| Moduli | Cubi trasportabili che si aprono in uno spazio X per Y già scavato |
| Scale | Eccezione ai cubi: costruzione immediata sul posto con 2 terriccio, senza officina, laboratorio, Robbie o energia |
| Personaggio | 30 livelli, esperienza da scoperte e capacità passive; cura e tuta distinte |
| Astronave | 10 livelli di sviluppo, tre piani iniziali, upgrade interni e moduli esterni visibili |
| Robbie | Cura, batterie, segnale, accessori e trasporti automatici su percorsi esplorati |
| Creature | 36 specie originali senza combattimenti; massimo 3 compagni sbloccati gradualmente |
| Sopravvivenza | Intermedia; soccorso e carico recuperabile senza scadenza |
| Valute | Cristalli da scoperte e giacimenti finiti; upgrade senza obbligo di commercio |
| Grafica | Alieni amichevoli e simpatici, resa 3D sfaccettata come [Space Digger](../../refs/Space_Digger.png) |

## Cataloghi autorevoli

| File JSON | Contenuto | Vista leggibile |
| --- | --- | --- |
| [resources.json](../../design/v1/resources.json) | 38 risorse grezze e 38 materiali lavorati; fonti, strumenti, icone e materiali | [Risorse](resources.md) |
| [recipes.json](../../design/v1/recipes.json) | 85 ricette con quantità, postazione, ricerca, energia e durata | [Ricette](recipes.md) |
| [modules.json](../../design/v1/modules.json) | 40 moduli e infrastrutture; ingombri, cubi, porte, consumi e funzioni | [Moduli](modules.md) |
| [planets.json](../../design/v1/planets.json) | 12 pianeti, risorse, pericoli, budget e obiettivi di rilievo | [Pianeti](planets.md) |
| [research.json](../../design/v1/research.json) | 18 nodi di ricerca, visite e rilievi distinti | [Progressione](research.md) |
| [upgrades.json](../../design/v1/upgrades.json) | 52 percorsi, 137 acquisti di livello; personaggio, nave, Robbie e strutture | [Upgrade](upgrades.md) |
| [currencies.json](../../design/v1/currencies.json) | Lumen comuni e 11 nuclei accordati | [Economia](upgrades.md) |
| [creatures.json](../../design/v1/creatures.json) | 36 specie, fiducia, habitat, cure, compatibilità e aiuti | [Creature](creatures.md) |
| [hazards.json](../../design/v1/hazards.json) | 26 pericoli con segnali, effetti, contromisure e recupero | [Pericoli](hazards.md) |
| [services.json](../../design/v1/services.json) | 11 operazioni di cura, manutenzione e rifornimento | [Cura](care-and-caves.md) |
| [tools.json](../../design/v1/tools.json) | Estrattore, scanner, raccolta, plasma e risonatore | Catalogo interattivo |
| [items.json](../../design/v1/items.json) | Culla di stasi riutilizzabile | Catalogo interattivo |
| [progression.json](../../design/v1/progression.json) | Prime azioni, fasi, dipendenze, ritorni e completamento | [Progressione](research.md) |
| [balance.json](../../design/v1/balance.json) | Fabbisogno grezzo, scorte garantite e costruzioni di riferimento | Rapporto di verifica |
| [gui.json](../../design/v1/gui.json) | Schermate, stati, messaggi, input, accessibilità e pianificatore | [Interfaccia](interface.md) |
| [implementation.json](../../design/v1/implementation.json) | Ordine delle feature, migrazioni e verifiche | [Contratto](ai-implementation-contract.md) |

## Asset e anteprima

- [Anteprima interattiva](../../design/preview/index.html): flussi di costruzione, navigazione, inventario e cura; cataloghi filtrabili e catene degli ingredienti. Funziona anche senza server.
- [Manifest degli asset](../../assets/design/manifest.json): 289 icone SVG, 76 superfici periodiche SVG e 76 risorse `StandardMaterial3D` per Godot.
- [Tavola delle 36 creature](../../assets/design/concepts/creatures-36-alien.png): reference di produzione 3D, nell’ordine del catalogo.
- [Schema dei cataloghi](../../design/catalog.schema.json): contratto JSON Schema dell’oggetto aggregato.
- [Rapporto di verifica](validation-report.json): riferimenti, raggiungibilità e copertura delle valute.
- [Controllo anteprima](preview-check-report.json): 401 esecuzioni di schermate, stati e schede con DOM simulato; verifica visiva nel browser non eseguita perché il protocollo dei file locali è bloccato dalla policy.
- [Controllo materiali Godot](material-check-report.json): importazione e caricamento dei 76 materiali e delle relative texture con Godot 4.6.3 in un progetto temporaneo isolato.

Le icone e le superfici sono asset originali utilizzabili nel prototipo. I materiali Godot collegano le superfici SVG e i parametri metallicità e ruvidità. La tavola 3D è una reference: modelli animati, rig e mappe PBR definitive restano attività di produzione.

Prima integrazione runtime: il tutorial fino al laboratorio su Ocra legge `progression.json:ocra_tutorial`. Per aggiungere compiti di Robbie, messaggi e condizioni vedere [la guida di authoring](../technical/robbie-tutorial-authoring.md). La fabbricazione e il trasporto del cubo laboratorio sono attivi; questo non implica l'implementazione degli altri moduli o dei 12 pianeti.

## Risultati di verifica e limiti

Il validatore controlla che pianeti, ricerche, risorse, stazioni e rilievi siano raggiungibili considerando prerequisiti e disponibilità degli ingredienti. Controlla inoltre quantità, riferimenti, menu di costruzione, file degli asset e bilancio delle valute. I 7.120 Lumen garantiti coprono i 3.840 richiesti da tutte le ricerche e tutti i livelli di upgrade del catalogo.

La verifica di raggiungibilità è qualitativa: non simula una partita, il tempo di scavo, i consumi di ossigeno o la resa numerica di ogni giacimento. Questi aspetti hanno obiettivi espliciti nei cataloghi e richiedono prove del gioco. L’anteprima GUI non è una scena Godot e non modifica salvataggi.

Il bilancio dei materiali espande le ricette per una costruzione di ciascun modulo, gli habitat necessari a ospitare tutte le specie, tre culle e tutti gli upgrade acquistati una volta. Le scorte garantite coprono questa base con una riserva; carburante, cibo, medicine ripetute e costruzioni aggiuntive richiedono raccolta o coltivazione ulteriore. I materiali comuni ricorrono anche sui pianeti successivi per ridurre i viaggi obbligati verso l’inizio.
