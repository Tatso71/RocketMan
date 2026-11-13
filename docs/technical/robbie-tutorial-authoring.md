# Compiti di Robbie

Il tutorial di Ocra fino al primo laboratorio e definito in `design/v1/progression.json`, sezione `ocra_tutorial`. I testi effettivi dei balloon e degli obiettivi sono centralizzati in `design/v1/robbie_texts.json`. Il runtime legge direttamente questi dati; non modificare l'HTML generato per cambiare il gioco.

Dal 13 novembre nella variante umano il percorso e': raccogliere 8 ferro, 3 rame e 1 cristallo, liberare una stanza sicura e supportata 4 x 3 m e posare il laboratorio. La sagoma e' un ordine completo: Robbie scarica alla nave, fa preparare solo i componenti mancanti del primo progetto, ritira, consegna e monta. Da scorte vuote servono 2 lotti strutturali e 1 elettronico. Non richiedere un ritorno al computer per ordinare: resta disponibile per stato, scorte e anticipazioni manuali facoltative. La direzione manuale del 12 novembre e' storica e superata per l'umano; Robbie pilotabile mantiene ordini, ritiro e montaggio manuali e i suoi override `robbie` nel catalogo testi.

Gli ID delle tappe `laboratory_cube` e `carry_laboratory` restano stabili e significano produzione e ritiro dei componenti: le condizioni reali restano `components_produced` e `components_collected`, non eventi di pickup di un cubo. Titoli e aiuti per l'umano spiegano che puo gia posare la sagoma mentre Robbie prepara e trasporta; non aggiungere obblighi manuali o cambiare ID/condizioni per aggiornare il testo. Le scale sono gratuite. I costi di produzione/montaggio sono in `prototype_components.json`, non nelle vecchie ricette di cubi del design completo.

## Laboratorio Dei Testi

Aprire `scenes/labs/robbie_text_lab.tscn` in Godot e premere F6. La scena e indipendente dalla partita: non avvia il tutorial e non tocca i salvataggi. A sinistra ricerca ed elenco; al centro titolo, priorita, balloon e dettaglio obiettivo; a destra anteprima dal vivo, scorrevole anche per testi lunghi. Per i messaggi normali il dettaglio obiettivo non e utilizzato.

Salva testi o Ctrl+S aggiorna il JSON; una copia precedente rimane in `robbie_texts.json.bak`. Il salvataggio rifiuta titoli/balloon vuoti, priorita fuori 0..100 e modifiche esterne successive all'apertura. Ricarica richiede conferma se ci sono modifiche non salvate; anche la chiusura della finestra avverte. F8 e l'arresto forzato dell'editor interrompono il processo senza poter chiedere conferma: salvare prima. Riavviare una partita gia aperta per rileggere il catalogo.

Gli ID sono stabili: `welcome`, `cargo_full`, `cargo_near_station` (variante presso un banco), pericoli acqua/gas/petrolio e `ocra/<id tappa>` per il tutorial. Non cambiare ID per correggere una frase: i salvataggi li usano per gli aiuti gia letti. Le regole e gli eventi restano in `progression.json`; i campi `title_it`, `hint_it`, `detail_it` fungono da fallback per tappe nuove. Una nuova tappa appare automaticamente nella scena lab; salvandola, il testo passa al catalogo centralizzato. Non cambiare ingredienti o condizioni di completamento scrivendo soltanto una frase: le azioni di gioco non dipendono dal testo.

## Aggiungere Una Tappa

Inserire una voce in `steps`, nell'ordine desiderato. Non occorre aggiungere messaggi o rami nel codice della GUI:

```json
{
  "id": "inspect_bed",
  "title_it": "Controlla il letto",
  "hint_it": "Clic destro sul letto al piano centrale. Potrai tornare qui per recuperare energia e integrita della tuta.",
  "detail_it": "Alloggio / piano centrale",
  "action": "help",
  "complete_when": {"fact": "bed_inspected"}
}
```

Gli ID devono essere univoci e stabili. Titolo e dettaglio compaiono nel pannello obiettivo; `hint_it` e il balloon di Robbie, finche non esiste la voce corrispondente nel catalogo testi. La numerazione, la barra, il richiamo manuale, la ripetizione ogni 25 secondi e il salvataggio si adattano alla lista. Gli avvisi di pericolo hanno precedenza; silenziare i balloon non nasconde l'obiettivo e non blocca il progresso.

`complete_when` accetta una condizione:

- `{"fact": "nome_evento"}`: un evento semantico e realmente avvenuto.
- `{"counter": "mined_cells", "at_least": 2}`: il contatore ha raggiunto la soglia intera positiva.

Gli eventi gia avvenuti restano validi anche se il giocatore esegue le azioni in un ordine diverso. Non serve ripetere un'azione perche il messaggio non era ancora apparso. `finish_when` termina l'intero percorso: per aggiungere compiti dopo il laboratorio occorre spostare anche questa condizione finale.

## Eventi Disponibili

| Evento | Origine |
| --- | --- |
| `workshop_entered` | Personaggio arrivato al piano inferiore |
| `workshop_interacted` | Apertura dei comandi dell'officina |
| `hatch_opened` | Botola effettivamente aperta |
| `mined` / `mined_cells` | Rimozione riuscita di una cella, non un impulso o una scansione |
| `ladder` | Scala realmente costruita e pagata |
| `inventory_opened` | Inventario aperto da qualsiasi accesso |
| `bed_inspected` | Apertura del pannello del letto |
| `lab_materials_ready` | 6 pietra + 4 rame nel carico comune o nel deposito locale raggiungibile |
| `lab_fabrication_started` | Pagamento unico e lavorazione avviata sul banco |
| `lab_cube_crafted` | Cubo pronto fisicamente sul banco, oppure cubo pagato da un salvataggio precedente |
| `lab_cube_carried` | Cubo preso con Spazio e portato in mano |
| `lab_cube_dropped` | Cubo posato con Spazio prima dell'attivazione |
| `lab_room_ready` | Stanza 4 x 3 libera, asciutta, sostenuta e nel raggio locale |
| `lab_cube_deployed` | Cubo consumato e montaggio iniziato |
| `lab_built` | Laboratorio attivo dopo il montaggio |
| `deposited`, `lamp_crafted`, `lamp_placed`, `pump_built` | Operazioni completate nei sistemi esistenti |

Gli eventi emessi da un'azione riuscita hanno automaticamente anche un contatore con lo stesso nome: `{"counter": "ladder", "at_least": 3}` richiede tre scale costruite. `mined_cells` e l'alias leggibile del contatore `mined`. Le osservazioni continue del mondo aggiornano solo i fatti: non incrementano contatori, e neppure il caricamento di un salvataggio inventa nuove azioni.

Per una nuova azione di gioco emettere una volta `world.guide_event("nome_evento")` solo dopo il successo della transazione; non occorrono modifiche al modello per contarla. Non assegnare esperienza o materiali da un messaggio. Le azioni di pulsante supportate sono `help`, `fabricate_lab`, `place_lab` e `inventory`; comandi nuovi richiedono un gestore esplicito nella GUI.

## Contratto Runtime Attuale

Nella variante umano i progetti sono ordini completi e seguono una FIFO stretta nell'ordine originale di posa, mantenuto dopo salvataggio/caricamento. La nave produce solo i componenti mancanti del primo progetto dopo aver contato scorte pronte e uscite gia pagate, anche da ordini manuali; il residuo si arrotonda ai lotti esistenti. Niente scorte minime o produzione per progetti successivi. Robbie deve ritirare i componenti reali, raggiungere il cantiere e restare sul posto per montare: nessun pagamento remoto. Un primo progetto bloccato ferma la coda, senza saltare ai successivi. Stato e aiuti devono indicare il motivo concreto, per esempio ferro mancante, botola chiusa, stoccaggio pieno o mancanza di energia. Annullare il primo permette di avanzare.

Clic destro su un laboratorio raggiungibile apre il computer per controllare stato/scorte o anticipare manualmente la produzione. Gli ordini pagano e riservano ingredienti ed energia alla richiesta e avanzano in sequenza per postazione; laboratori distinti lavorano indipendentemente. Coda pagata e uscita pronta persistono nei salvataggi, anche se manca energia o lo stoccaggio e' pieno. Distanza dalla nave e profondita non fermano il robot; botole chiuse, roccia e liquidi pericolosi possono bloccarlo. Costi, ricette, tempi, energia, capienze, icone e accesso fisico restano invariati. Consultare README, [specifica approvata](../superpowers/specs/2026-11-13-project-orders-design.md) e mappa di produzione per regole aggiornate.

## Note Storiche Del Prototipo A Cubi

Le sezioni seguenti descrivono il sistema precedente, non il runtime attuale: cubi da trasportare, materiali comuni, limiti radio, ricette e comandi di compatibilita qui citati sono superati. Non usarli per aggiungere compiti o testi al tutorial corrente.

Le nuove partite iniziano senza materiali nella nave, nel giocatore o in Robbie. I due carichi si sommano sempre per disponibilita, pagamento e trasferimenti; il raggio radio continua a limitare il movimento del robot e la raccolta di nuove risorse, non l'uso dei materiali gia trasportati. Il deposito della nave o del laboratorio contribuisce solo quando quel banco e raggiungibile.

La ricetta `recipe_cube_lab` costa 6 pietra + 4 rame e 0.01 kWh. Crea verifica e paga atomicamente all'avvio, riservando il singolo slot di uscita del banco: non occorre spazio nello zaino. La produzione dura 5 / 3.33 / 2.5 secondi ai livelli I / II / III del laboratorio e produce attualmente un laboratorio di livello I. Il cubo si materializza sul banco con una barra; il lavoro continua chiudendo il pannello e persiste anche a meta. Un banco sotterraneo spento o senza energia sospende il lavoro pagato senza perderlo.

Spazio vicino al cubo lo prende; Spazio mentre lo si trasporta lo posa senza saltare. Un solo cubo puo stare in mano, separato dalle risorse dello zaino. Durante il trasporto lo strumento non puo scavare. Clic destro sul cubo posato apre Attiva laboratorio: solo ora viene verificato l'intero ingombro 4 x 3. Se non entra, il cubo resta recuperabile con tratteggio rosso e motivo del blocco; non si paga nulla. Se valido, viene consumato quel cubo e parte il montaggio di 5 s. Il personaggio puo stare nell'ingombro.

`fabrication_state.gd` salva lavori pagati, cubi pronti/posati e il cubo in mano. Il banco di bordo e i cubi che viaggiano sulla nave vengono trasferiti allo stato nave al decollo e importati una sola volta al nuovo atterraggio. Le lavorazioni locali restano sul pianeta; non si simulano pianeti non visitati o tempo offline. I vecchi cubi pagati nello zaino vengono materializzati quando si preme Spazio; le scorte reali gia presenti nei salvataggi non vengono cancellate.

I vecchi cantieri non finanziati conservano un comando esplicito di compatibilita con materiali comuni, senza popup automatici. Il laboratorio e l'unica ricetta iniziale. Solo dopo il completamento del primo laboratorio si sbloccano luce, pompa e ventilatore, sia a bordo sia nei laboratori sotterranei; lo sblocco resta acquisito anche spegnendo un laboratorio o caricando vecchi salvataggi. Scale sempre immediate con B, per 2 terra e senza cubo. La progressione completa e lo strato limite di Ocra restano da definire.

## Cubi Di Servizio

Le tre ricette di questa tranche sono in `progression.prototype_fabrication`, validate e normalizzate da `ocra_catalog.gd`. Sono ricette semplificate del prototipo, non la futura economia dei 12 pianeti. `mod_gas_filter` identifica nel catalogo completo la famiglia del ventilatore gas; nome, ingredienti e tempi attuali sono quelli della tranche.

| Oggetto | Ingredienti | Fabbricazione L1 | Apertura | Ingombro |
| --- | --- | --- | --- | --- |
| Luce | 1 terra + 1 rame | 2.5 s / 0.004 kWh | 2.5 s | 1 x 1 m |
| Pompa acqua | 3 pietra + 4 rame | 4 s / 0.008 kWh | 4 s | 2 x 2 m |
| Ventilatore gas | 2 pietra + 3 rame | 4 s / 0.006 kWh | 4 s | 2 x 2 m |

Il livello del banco divide i tempi di fabbricazione per 1 / 1.5 / 2. Tutti i cubi usano lo stesso slot di uscita riservato, carico comune, Spazio per presa/posa e attivazione senza un secondo pagamento. Nome e colore del contenuto persistono in lavori, cubi, strutture e trasferimenti sulla nave. Ogni riga ha il proprio Crea e i propri conteggi rossi/verdi. Le tre ricette non compaiono prima del primo laboratorio e le chiamate dirette rispettano lo stesso blocco.

Le tre utenze di servizio richiedono un laboratorio operativo entro il suo raggio di collegamento. Questa rete nave/laboratorio resta a raggio; i nuovi cavi industriali collegano invece convertitori gas, fornaci e serre, come descritto in `industry-and-crops.md`. I connettori energetici non sono ancora implementati. La luce illumina; la pompa tollera acqua ma non gas; il ventilatore tollera gas ma non acqua. Pompa e ventilatore rimuovono rispettivamente 0.7 e 0.35 unita/s attraverso celle scavate collegate entro 3 passi Manhattan, mai attraverso roccia. Assorbono 0.03 / 0.02 kWh/s da attivi, 0.08 / 0.05 durante apertura. La lista dei dispositivi alimentati viene fissata all'inizio del passo: nessuna rimozione retroattiva alla conclusione e nessuna azione oltre la durata realmente coperta dalla batteria.

Clic destro su un dispositivo attivo apre Accendi/Spegni. Stato e quantita cumulativa rimossa sono salvati; il laboratorio va mantenuto in una zona sicura per alimentare i dispositivi. L'acqua/gas rimossi vengono eliminati, senza serbatoi, filtri consumabili o recupero di risorse in questa versione.

Le barre sul laboratorio e il pannello energia mostrano due grandezze distinte: carica reale della batteria condivisa della nave, e assorbimento attuale ripartito fra banco, luci, pompe e ventilatori. La capacita segue gli upgrade della nave. I segmenti colorati rappresentano consumo attuale rispetto al nominale delle utenze installate; non viene introdotto un limite locale di potenza o una seconda batteria. Il pannello indica kWh/min e autonomia dell'intera rete, evitando una falsa stima indipendente per laboratorio.

`supplying_lab` seleziona il laboratorio operativo piu vicino entro il collegamento attuale, e `power_reports` aggrega tutte le barre in un unico passaggio: un dispositivo non viene contato su due laboratori. I dispositivi spenti/non alimentati restano visibili fra le utenze installate quando hanno un collegamento logico. La conversione della rete nave/laboratori ai cavi fisici e i connettori restano da implementare; i cavi industriali gas-energia sono gia separati e funzionanti.

## Verifica

```powershell
node tools/design/build.mjs
node tools/design/validate.mjs
node tools/design/check-preview.mjs
godot --headless --path . -s res://tests/integration/ocra_onboarding_smoke.gd
godot --headless --path . -s res://tests/integration/physical_fabrication_smoke.gd
godot --headless --path . -s res://tests/integration/utility_cubes_smoke.gd
```

Il test attraversa la nave e scava realmente la stanza, senza la fixture di gallerie preesistenti. `-- --capture` senza `--headless` verifica pannello obiettivo, balloon, fabbricazione, distanza di Robbie e laboratorio a 720p/1080p. I test unitari coprono l'aggiunta di un compito dai dati, ordine libero, richiamo, priorita dei pericoli e salvataggi nativi/JSON.
