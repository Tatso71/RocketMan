# Contratto di implementazione per l AI

## Autorità e formato

| Regola | Contratto |
| --- | --- |
| Fonte modificabile | `design/v1/*.json`, indicizzati da `manifest.json` |
| File derivati | Tabelle in `docs/design`, `design/preview/index.html`, schema e asset generati; rigenerare dopo modifiche ai JSON |
| ID | Stabili, univoci, in inglese; etichette `name_it` separate; nessuna logica basata sull’etichetta |
| Riferimenti | Un ID deve esistere prima del caricamento; rifiutare cataloghi parzialmente validi |
| Quantità | Interi positivi per ingredienti e risultati; inventari misurati in unità astratte |
| Coordinate | Celle intere da 1 m; Y positivo in profondità; conversione con floor anche per coordinate negative |
| Geometria | Ingombro X per Y in sezione; nessuna equivalenza automatica con metri cubi |
| Tempo | Secondi di simulazione; menu modali e pausa congelano attività locali e avvisi |
| Energia | Potenza kW × secondi / 3.600 = energia kWh; costi di ricetta dichiarati a parte |
| Stato runtime | Il codice esistente resta autorevole fino all’implementazione e alla migrazione della singola feature |

## Protocolli di costruzione

```text
ingredienti locali → fabbricazione atomica → item cubo
→ trasporto fisico → preview X per Y → verifica e prenotazione celle
→ consumo di un cubo → montaggio → collegamento → modulo attivo
```

Le scale sono l'eccezione esplicita: il personaggio le costruisce sul posto, istantaneamente, con 2 terriccio (B / Y). Nessun cubo da fabbricare o trasportare, popup, postazione, laboratorio, Robbie, segnale o batteria; nessun timer. Prima si verifica la cella libera e raggiungibile, poi pagamento locale e scala attiva si confermano atomicamente. Un tentativo non valido non consuma nulla. L'ID storico `recipe_cube_ladder` rimane stabile, ma la categoria è `manual_construction`, la postazione è `null`, tempo ed energia sono zero e l'output è direttamente nel mondo, non nello zaino. Queste regole prevalgono sul protocollo generale dei cubi.

| Condizione | Comportamento richiesto |
| --- | --- |
| Manca spazio per il cubo prodotto | Non consumare ingredienti |
| Celle ancora solide | Evidenziarle; nessuno scavo automatico |
| Pavimento incompleto o pericolo | Rifiutare con un motivo specifico |
| Attore nella futura collisione | Sospendere il montaggio; non schiacciare o teletrasportare |
| Modulo incompleto o senza energia | Stato `deploying` o `offline`; nessuna funzione gratuita |
| Annullamento | Restituire lo stesso cubo, non cubo più ingredienti |
| Smontaggio | Svuotare scorte e creature, restituire un cubo con livello e danni conservati |
| Upgrade | Nessun cambio di ingombro senza un nuovo progetto di espansione |
| Primo laboratorio | Ricetta nell’officina già presente: 6 pietra + 4 rame; non richiede un laboratorio |

Ogni modulo dichiara porte locali, aggancio, ingombro e statistiche per livello; solo i moduli a cubo hanno carico chiuso e montaggio. La scala occupa 1 x 1 m nel mondo e zero unità di cubo trasportato. La maggior parte degli arredi è sul piano di fondo e non blocca il personaggio; porte e camere di compensazione usano i rettangoli metrici dichiarati. Lo spazio resta riservato contro sovrapposizioni di costruzione.

## Proprietà dello stato e transazioni

| Oggetto | Proprietario unico |
| --- | --- |
| Cristalli e registro ricompense | Campagna |
| Esperienza, passive, salute e tuta | Personaggio della campagna |
| Stiva, carburante, batterie, upgrade e danni nave | Astronave della campagna |
| Zaino, carico e batterie Robbie | Inventari globali della campagna |
| Cubi dispiegati, depositi, reti, fluidi e terreno | Singolo avamposto |
| Creatura in habitat | Avamposto; spostare la proprietà quando entra nella culla |
| Creatura nella culla o in spedizione | Campagna; mai una copia nell’avamposto |
| Carico perso dopo soccorso | Deposito recuperabile nell’avamposto, con ID incidente persistente |

Inventario, pagamento, output e registro ricompense si confermano nella stessa transazione. Il fallimento non modifica nessuna delle parti. Il caricamento valida tutto prima di sostituire lo stato vivo. Il magazzino della nave non è un deposito remoto.

## Prerequisiti e progressione

- `requires_all`: devono essere presenti tutti gli ID.
- `requires_any`: se la lista non è vuota, basta almeno un ID.
- `requires_planet_visits`: basta un atterraggio valido.
- `requires_surveys`: occorrono tutti e tre gli obiettivi locali del pianeta.
- `requires_functional_module`: il modulo deve essere attivo e raggiungibile.
- `cost_items`: materiali consumati fisicamente presso la postazione.
- `cost_currency`: addebito nel portafoglio globale.
- Gli upgrade hanno rango iniziale 0; `levels[0]` è il primo acquisto. Per i moduli, il livello installato visualizzato è `display_installation_level`.
- Nessuna passiva, specie o acquisto facoltativo è necessario per risolvere un accesso obbligatorio.

Le ricerche locali non richiedono il proprio rilievo completo: per esempio, visitare Ferrum e raccogliere ferro abilita la metallurgia che serve a completare i lavori del rilievo. La rotta finale richiede gli undici rilievi precedenti.

## Coerenza dei materiali

Le ricette sono trasformazioni di unità di inventario, non equazioni chimiche o masse reali. La fabbricazione deve rispettare ingredienti e risultati dichiarati, senza introdurre sottoprodotti impliciti. Le colture richiedono acqua, materiale di avvio, tempo ed energia. Le specie non generano metalli rari o cristalli dal nulla. I cristalli geologici tecnici e la valuta Lumen hanno ID diversi.

## Compatibilità con il prototipo

| Comportamento attuale | Evoluzione prevista |
| --- | --- |
| Laboratorio posato pagando materiali | Nuove costruzioni tramite cubo; laboratori esistenti conservati |
| Tre pianeti con ID `ochre`, `verdant`, `frost` | Alias di migrazione in `implementation.json`; mantenere i vecchi seed negli avamposti esistenti |
| `crystal` nello stock del prototipo | Conversione una tantum esplicita, validata e registrata; mai interpretarlo automaticamente come portafoglio |
| Nessun consumo reale di ossigeno | Introdurlo con cura, UI di ritorno e soccorso nella feature dedicata |
| Carburante provvisorio ottenuto dal terriccio | Nuova ricetta acqua ed energia; vecchi salvataggi conservano carburante già posseduto |
| Upgrade cargo, segnale e lab I–III | Conservare valori di base e livelli migrabili; non ricaricare gratis capacità aggiunte |
| Habitat come arredo | Tenuta della stanza e qualità dell’aria restano sistemi separati |

## Ordine e verifiche

Usare `implementation.feature_order`. Ogni feature comprende il minimo di interfaccia necessario a usarla; la fase GUI finale consolida flussi, accessibilità e controller. Non attendere l’ultima fase per rendere utilizzabile una funzione.

| Area | Verifica funzionale obbligatoria |
| --- | --- |
| Cubi | Primo laboratorio possibile, ingombro rispettato, nessun doppio pagamento, salvataggio durante montaggio |
| Economia | Ricompense una sola volta, rimborso senza duplicazione, riserva per la ricerca |
| Personaggio | Esperienza da eventi unici, cure disponibili, deposito recuperabile persistente |
| Nave | Agganci occupati correttamente, portello libero, costi viaggio una sola volta |
| Caverne | Volumi finiti, avviso prima dei crolli, materiali obbligatori raggiungibili |
| Robbie | Percorso esplorato, trasferimenti atomici, carico conservato in blocco e soccorso |
| Creature | Habitat prenotato prima del trasporto, compatibilità e cura; nessuna morte fuori sessione |
| GUI | Mouse e controller, ragione del blocco visibile, nessun click che attraversa il menu verso lo scavo |

Eseguire `node tools/design/validate.mjs` per i controlli statici. Il risultato non sostituisce prove Godot né test di bilanciamento e non certifica l’importazione 3D degli asset.
