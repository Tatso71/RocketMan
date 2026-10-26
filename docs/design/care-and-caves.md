# Personaggio astronave e caverne

Fonte autorevole: [rules.json](../../design/v1/rules.json), sezioni `player_progression`, `ship_progression`, `survival`, `robbie_care` e `caves`. Le operazioni hanno costi ed effetti in [services.json](../../design/v1/services.json).

## Livello e cura del personaggio

| Sistema | Regola |
| --- | --- |
| Livello | 1–30; soglie esperienza esplicite nel JSON |
| Esperienza | Prime scoperte, specie osservate e legate, moduli distinti, pericoli risolti, rilievi e luoghi unici |
| Ripetizioni | Scavare, fabbricare ripetutamente e ricatturare la stessa specie non producono esperienza |
| Crescita | +2 salute per livello; bonus moderati di resistenza ogni 5 livelli |
| Specializzazioni | Esploratore, ingegnere, naturalista; 10 punti complessivi, redistribuibili a bordo |
| Salute | Ferite ed esposizioni; cura base gratuita a bordo, infermeria e gel sul campo |
| Tuta | Integrità distinta dalla salute; perdite, contaminazione, protezione termica e pressoria |
| Ossigeno | 12 minuti base nelle zone non respirabili; avvisi e stima del ritorno |
| Riposo | Letto di bordo o branda; fame sostituita da un pasto facoltativo per spedizione |
| Soccorso | Salute 40, tuta 25; metà dei materiali in un deposito sicuro senza scadenza; esperienza, cristalli e creature conservati |

La prima zona didattica di Ocra sospende i consumi pericolosi. Gli altri ambienti introducono i misuratori quando servono. Il limite di ossigeno non deve diventare una sorpresa senza una via di ritorno leggibile.

## Livello e cura dell astronave

| Sistema | Regola |
| --- | --- |
| Livello | 1–10 da traguardi diversi di sviluppo e spedizione; nessuna esperienza da azioni ripetute |
| Geometria | Cabina, alloggio e officina iniziali conservati |
| Agganci esterni | Da 2 a 6 con il livello; stive, batterie, motori e radar visibili |
| Upgrade interni | Scafo, cargo, batterie, propulsori, piedi, ossigeno, radar, banco strumenti, clima, culle e archivio |
| Danni | Atterraggio, ambiente non schermato e soccorso; causa sempre visibile |
| Riparazione scafo | 2 pietra + 1 rame per 25 integrità, a bordo |
| Controllo periodico | Avviso ogni 5 voli; nessuna rottura casuale solo perché è scaduto un timer |
| Carburante | Elettrolisi di acqua, poi propellente avanzato; controllo di decollo, rotta e riserva |
| Emergenza | Ricarica solare senza materiali; rimorchio verso Ocra senza costo in cristalli o oggetti unici |
| Cura di bordo | Ripristino del personaggio e servizio Robbie; non consumare la riserva di viaggio per servizi facoltativi |

## Esplorazione e gestione delle caverne

| Sistema | Regola |
| --- | --- |
| Griglia | Celle da 1 m; chunk 32 × 32; geometria e collisione derivano dalle stesse coordinate |
| Avvio | Terreno integro sotto il portello; pozzo di 2 m scavato dal giocatore |
| Scale | Costruzione manuale immediata sul posto con 2 terriccio; niente cubo, officina, laboratorio, Robbie o energia |
| Strati | 0–12, 13–40, 41–90, 91–160 e 161–240 m |
| Sostegni | Avviso sopra 6 m senza supporto, rischio oltre 9 m; 10 secondi di segnale; primo strato di Ocra protetto |
| Crolli | Detriti rimuovibili con lo strumento iniziale; nessuna cancellazione di moduli o oggetti obbligatori |
| Geologia | Terreno morbido, sedimenti, roccia compatta, cavità e ancoraggi indistruttibili da aggirare |
| Scanner | Legge una parete adiacente prima di aprire una sacca; nessuna rivelazione a distanza tramite zoom |
| Acqua | Quantità finita; pompe e serbatoi verificano la capacità di destinazione |
| Gas | Diffusione locale, isolamento e filtraggio; aria respirabile distinta dallo spazio vuoto |
| Abitabilità | Perimetro chiuso, compensazione, supporto vitale, energia e qualità dell’aria |
| Reti | Energia, aria, acqua e segnale; portate, priorità e interruzioni visibili |
| Mappa | Terreno visitato, risorse scansionate, gas, acqua, sostegni, reti, habitat, rotte Robbie e ritorno |
| Costruzione | Prenotazione ingombri X per Y, porte accessibili e uscita sempre preservata |
| Persistenza | Scavi, giacimenti, fluidi, strutture, creature, depositi di soccorso e percorsi salvati per avamposto |

## Cura di Robbie

| Evento | Risposta |
| --- | --- |
| Batteria bassa | Prenotare energia per il ritorno prima di accettare un trasporto |
| Batteria esaurita | Attesa al nodo sicuro; carico conservato e recuperabile |
| Integrità zero | Arresto recuperabile; Robbie non viene distrutto definitivamente |
| Percorso ostruito | Fermarsi all’ultimo punto sicuro e segnalare una sola volta |
| Fuori segnale | Attesa; solo il livello avanzato permette brevi tratti con riserva di batteria verificata |
| Ricarica | Officina della nave o stazione Robbie |
| Riparazione | Materiali locali e costo visibile; recupero di emergenza se il giocatore è bloccato |

Il suo lavoro automatico sposta oggetti tra punti conosciuti. Non scava, non esplora zone sconosciute e non trasforma i magazzini in inventari remoti.
