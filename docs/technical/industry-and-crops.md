# Industria, Condotti E Colture

Tranche giocabile del prototipo, non implementazione dell'intera economia a 12 pianeti. Parametri e ricette: `design/v1/prototype_industry.json`. I dati sono validati da `industry_catalog.gd` e uniti al catalogo di fabbricazione gia utilizzato dal laboratorio.

## Unita

Tutte si sbloccano con il primo laboratorio e seguono il sistema fisico: Crea al banco, cubo materializzato, presa/posa con Spazio, attivazione con clic destro e apertura temporizzata. Ingredienti pagati una sola volta dal carico comune piu deposito del banco vicino. Il montaggio usa la batteria nave; il funzionamento delle nuove macchine utilizza invece i collegamenti locali descritti sotto.

| Unita | Costo | Fabbricazione L1 | Apertura | Celle |
| --- | --- | --- | --- | --- |
| Fornace | 6 pietra + 4 rame | 6 s | 5 s | 3 x 2 |
| Convertitore gas | 4 pietra + 5 rame | 5 s | 4 s | 2 x 2 |
| Serra | 4 pietra + 4 terra + 2 lingotti rame + 2 vetro | 7 s | 6 s | 4 x 3 |

La fornace trasforma 2 rame in 1 lingotto in 12 s, oppure 2 pietra in 1 vetro in 10 s, a 0.2 kWh/s. Clic destro apre ordini, avanzamento e ritiro. Gli ingredienti vengono riservati all'avvio; un ordine puo attendere il collegamento energetico senza perdere risorse. Un solo prodotto occupa l'uscita, senza nuovo ordine fino al ritiro.

## Collegamenti

T, oppure l'icona condotti in basso a sinistra, apre la scelta fra tubo acqua, tubo gas, cavo energia e smontaggio. Posa immediata con clic sinistro, anche trascinando; clic destro/Esc termina. Ogni segmento da 1 m costa 1 rame, senza cubi, banco o batteria. Portata 3 m, linea libera, solo celle scavate. Il costo usa zaino + Robbie e deposito locale raggiungibile; duplicati o tentativi invalidi non pagano. Gli elementi sono non bloccanti e possono passare nello spazio occupato da scale e mobili.

Le reti dei tre tipi sono separate: si collegano solo facce cardinali dello stesso tipo. Incrociare acqua, gas ed elettricita non mischia le risorse. Una cella mancante spezza la rete immediatamente; non esistono collegamenti impliciti per vicinanza.

Le porte sono le celle inferiori sinistre delle macchine. Eccezioni: uscita energia del convertitore e uscita acqua della pompa sono inferiori destre. Gli anelli colorati sulle unita indicano le porte; le coordinate del convertitore compaiono nel suo pannello. Serve un segmento sulla cella della porta.

- Gas: un tubo deve entrare nelle celle effettivamente contenenti gas e collegarsi all'ingresso del convertitore. Prima occorre aprire la sacca: il terreno non viene attraversato dai tubi. Il gas esposto continua a diffondere ed e pericoloso.
- Energia: dal convertitore alla porta arancio di fornace/serra. Il convertitore brucia al massimo 0.04 volumi gas/s e rende 12 kWh per volume; accumula al massimo 12 kWh. Da pieno smette di consumare gas. Energia condivisa solo dalle utenze appartenenti alla sua rete; non ricarica la nave e non produce combustibile infinito.
- Acqua: uscita della pompa alla porta azzurra della serra. La pompa conserva fino a 8 volumi se la sua uscita ha un tubo; da scollegata mantiene il vecchio drenaggio che elimina l'acqua. Estrazione a 0.7 volumi/s, raggio 3 passi aperti, alimentata dal laboratorio come prima. Il serbatoio alimenta le serre collegate e conserva l'acqua nei salvataggi. Spegnere la pompa ne chiude anche l'uscita; senza energia nave non estrae nuova acqua, ma quella gia conservata rimane utilizzabile se la pompa e abilitata.

Più macchine condividono realmente acqua/energia: ogni prelievo riduce la riserva prima della macchina successiva. Più convertitori/pompe nella stessa rete sommano le riserve, senza duplicarle. Il menu della macchina mostra lo stato effettivo di collegamento o pausa. I lavori continuano mentre quel menu e aperto; movimento e danni ambientali sono sospesi come negli altri pannelli. Gli altri menu mantengono le regole precedenti. I pianeti non visitati non vengono simulati.

## Coltivazione

La nave parte con tre patate da semina, nessun altro seme e nessuna scorta mineraria. Le sementi sono una riserva comune separata dai posti dello zaino, visibile nell'inventario; viaggiano con la nave. Una serra richiede un seme, acqua nella condotta e energia per le luci. Mancanza d'acqua, energia, spegnimento o contaminazione fermano la crescita senza cancellarla.

| Coltura | Origine dei semi | Tempo | Acqua totale | Raccolto |
| --- | --- | --- | --- | --- |
| Patata | Nave, 3 iniziali | 45 s | 2 | 3 alimenti + 2 semi |
| Tubero ocra | Capsule di Ocra | 50 s | 2.5 | 3 alimenti + 2 semi |
| Verdura viridia | Capsule di Viridia | 40 s | 3 | 3 alimenti + 2 semi |
| Bacca brina | Capsule di Brina | 60 s | 1.5 | 3 alimenti + 2 semi |

Ogni coltura usa 0.02 kWh/s di crescita. L'acqua viene consumata progressivamente, non tutta alla semina. A maturazione non si consuma piu nulla; Raccogli richiede spazio per l'intero raccolto. I semi vengono aggiunti soltanto dopo il trasferimento riuscito del cibo. Inventario, selezione dell'alimento e Consuma recuperano 20 energia personale spendendo una porzione.

I siti delle capsule sono in `industry_catalog.seed_sites`: due per pianeta, a [-10,8] e [6,9] m. Si rivelano scavando il blocco; clic destro raccoglie due semi. Robbie segnala la prima capsula visibile. L'esaurimento della capsula e locale al pianeta, le sementi sono globali; tornare sul pianeta o ricaricare non concede nuovi semi dalla stessa capsula. Non si aggiungono tunnel iniziali o cavita artificiali.

## Smontaggio E Salvataggi

Scale sotterranee rimovibili con raggio del piccone, clic destro/Smonta scala, modalita smontaggio o Shift+B sotto il personaggio. Nessun rimborso di materie. Scale interne e collare nave, a coordinate negative, protetti. Le vecchie scale salvate come strutture vengono rimosse anche da quella lista per non ricomparire al caricamento. Tubi e cavi si rimuovono dal menu, separatamente nei punti di incrocio.

I salvataggi aggiungono `network` e `industry` per avamposto; lavori, prodotti, serbatoi e colture sono persistenti. `seed_bank` appartiene alla nave; la copia locale del sandbox e separata. Il caricamento della campagna non sovrascrive le sementi globali con copie storiche degli avamposti. Vecchi salvataggi senza il campo ricevono le sole tre patate iniziali una volta; una riserva salvata a zero resta a zero. Ripristino atomico: condotti nella roccia, duplicati, riserve impossibili o macchine senza struttura vengono rifiutati prima di cambiare la partita.

Verifica: `tests/unit/test_industry.gd` e `tests/integration/industry_smoke.gd`; quest'ultimo fabbrica e trasporta i cubi reali, usa prodotti fusi per la serra, interrompe le reti, ricarica durante lavori/coltivazione e controlla conservazione, raccolta e smontaggio. `-- --capture` con renderer nativo genera schermate a 720p/1080p in `reports/`.
