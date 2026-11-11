# Circuiti Acqua

Stato runtime: 11 novembre 2026. Per tutti i costi e la filiera industriale leggere la [mappa di produzione](../design/mappa-produzione.md). Laboratorio: componenti, poi montaggio sul posto; non trasporto di cubi stanza.

Aggiornamento playtest: le sacche naturali di gas sono temporaneamente sospese, senza cavita' residue nei nuovi mondi. La fisica del gas e il convertitore restano disponibili nei test isolati, ma non c'e' combustibile naturale per alimentare fornaci/serre nelle nuove partite. Nessuna energia gratuita sostitutiva; pompe e valvole acqua restano utilizzabili con la rete del laboratorio.

## Presa Stagna

Dopo il primo laboratorio, T / Presa stagna seleziona una sagoma 1 x 1 m. R ruota nelle quattro direzioni; clic sinistro monta, destro/Esc annulla. Costo: 2 strutturali + 1 elettronico dal carico accessibile.

Occupa una cella libera accanto a una faccia di roccia, anche sul soffitto, senza pavimento proprio. La roccia adiacente e' l'ancoraggio; oltre quel singolo blocco si trova il punto di prelievo. La presa nasce chiusa. Collega il tubo, poi clic destro / Perfora in tenuta con un estrattore compatibile selezionato. Non rimuove roccia, non concede minerali e non apre la falda. Rocce indistruttibili non valide.

Apri/Chiudi controlla il passaggio. Senza tubo la presa torna chiusa; riconnettere non la riapre. Smontarla lascia il foro tappato; rompere l'ancoraggio rimuove la tenuta e puo' liberare normalmente la falda. Strutture non sovrapponibili alla presa.

## Terminali

Estremita' non configurate: tappate. T / Terminale acqua configura gratuitamente un tubo gia' pagato, verso una cella libera adiacente senza tubo. Clic destro sceglie Scarico nel mondo oppure Aspirazione dal mondo; cambiare funzione richiude il terminale. Aprirlo e' esplicito.

- Scarico: acqua fisica nella cella ricevente; scende, riempie la vasca scavata e puo' traboccare. Celle piene, ostruite o contaminate da petrolio/acido fermano il trasferimento senza cancellarlo.
- Aspirazione: tocca acqua reale di una pozza/galleria. Nessuna aspirazione per raggio o attraverso pareti.
- Gravita': presa/aspirazione e scarico piu' basso, percorso che non salga oltre il livello d'acqua all'ingresso, 0.35 u/s. Nessun sifone o simulazione di pressione dinamica.

## Pompa Separata

2 x 2 m, 2 strutturali + 2 elettronici, ingombro supportato. Porte inferiori: ingresso sinistro e uscita destra, separate anche se adiacenti. Celle superiori non attraversabili dai tubi acqua. Il pannello permette di invertire le porte e accendere/spegnere. Frecce e colori distinguono i ruoli. Un tubo attorno alla pompa puo' creare un bypass reale.

Portata 0.7 u/s; aspirazione e mandata ciascuna entro 6 m dalla pompa, compreso il percorso. Buffer 8 u dal catalogo: da pieno non preleva altro. Consumo nominale 0.03 kWh/s dalla rete del laboratorio/nave. Spenta, danneggiata o senza alimentazione non trasferisce. Non elimina piu' acqua vicina per raggio.

Scarichi e serre condividono lo stesso budget di mandata, senza moltiplicare la portata. Il pannello mostra stato, flusso effettivo, totale aspirato, riserva e consumo. Consultarlo lascia avanzare insieme circuito e acqua fisica; il personaggio resta fermo/protetto come negli altri pannelli delle macchine.

## Reti E Industria

Tubi acqua/gas: 1 strutturale/m; cavi: 1 elettronico/m. Posa immediata con clic/trascinamento entro 3 m e linea libera; solo celle scavate. Duplicati/tentativi invalidi non pagano. Reti cardinali separate: un incrocio non mischia risorse. Tubi/scale non bloccano il personaggio.

Il gas continua ad alimentare i convertitori attraverso tubi nelle celle effettivamente contenenti gas; nuove prese stagne per gas/acido/petrolio non ancora implementate. Convertitore: 0.04 u gas/s, 12 kWh/u, buffer 12 kWh. Energia locale via cavi a fornaci/serre, non ricarica automaticamente la nave.

Fornace: 2 rame -> 1 lingotto in 12 s, oppure 2 quarzo -> 1 vetro in 10 s; 0.2 kWh/s locali. Serra: acqua da pompe collegate alla propria rete di uscita, energia locale, un seme. Colture e raccolti nella mappa. La nave parte con 3 semi di patata, nessuna scorta mineraria; altre sementi dalle capsule dei pianeti.

## Salvataggi E Limiti

`network`, `hydraulics`, `industry`, `hazards` per avamposto; sementi globali. Persistono prese, ruoli/aperture, direzione pompe, riserve e lavori. Portate/budget del tick non persistono. Restore atomico con controlli di coordinate, duplicati, tipi, riserve e sovrapposizioni. Limite di 200 prese/terminali verificato anche prima della posa.

Preferire una nuova partita per provare il nuovo comportamento delle pompe, senza cancellare vecchi file. Serbatoi della nave con bocchettoni, trasporto interplanetario di fluidi, pavimenti/volumi costruibili e upgrade dei dispositivi sono futuri, separati dalle ricette attive.

Previsti anche filtri per purificare l'acqua: modulo distinto dalla pompa e collegato alla condotta prima del ricevente. Qualita', contaminanti, costi e manutenzione restano da definire; il runtime attuale non distingue ancora acqua grezza e purificata.

Requisito futuro per le coltivazioni: la serra dovra' ricevere acqua adatta all'irrigazione, non soltanto acqua in quantita' sufficiente. Le fonti contaminate richiederanno filtrazione; soglie e conseguenze della qualita' insufficiente sono ancora da progettare.

Verifiche: `test_water_circuit.gd`, `water_circuit_smoke.gd`, `industry_smoke.gd`, `utility_cubes_smoke.gd`, `reservoirs_smoke.gd`. Il nuovo smoke nativo verifica posa orientata, click, sollevamento, conservazione, ingombri e salvataggi; `-- --capture` scrive schermate in `reports/`.
