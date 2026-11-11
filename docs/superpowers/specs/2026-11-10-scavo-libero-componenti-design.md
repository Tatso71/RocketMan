# Scavo libero e costruzione a componenti

Data: 10 novembre 2026. Branch: `codex/scavo-libero`.
Stato: approvato dal giocatore il 10 novembre 2026. Nessun commit o push autorizzato per questo lavoro.

## Intento

Scavare deve essere piacevole, non una sequenza di scarichi obbligatori. Il laboratorio deve mantenere un ruolo concreto senza costringere a scegliere e trasportare in anticipo un cubo diverso per ogni oggetto.

Il giocatore ha scelto di eliminare terra e pietra dalle risorse e dalle ricette. Rimangono tipi di terreno, con le proprie regole di scavo, ma non diventano oggetti nel carico. La nuova catena richiesta e': raccolta di minerali utili, produzione di componenti in laboratorio, montaggio della struttura sul posto.

## Approcci e scelta

1. Cubi monouso per ogni struttura, come nel prototipo attuale: conservano il flusso fisico ma obbligano a decidere cosa costruire prima di partire. Il giocatore chiede di sostituirli.
2. Costruzione diretta dai minerali sul posto: e' semplice, ma elimina la distinzione richiesta tra produzione e montaggio e indebolisce il laboratorio.
3. Componenti versatili prodotti in officina: e' l'approccio scelto dal giocatore. Due soli tipi iniziali, impilabili, permettono di decidere sul posto cosa montare.

Si mantiene Godot 4 e l'architettura del prototipo esistente. Non e' una riscrittura del gioco.

## Regole richieste

- Solo i minerali e gli altri oggetti utili occupano carico. Terra, pietra e roccia compatta scavata non producono carico ne' impediscono lo scavo con inventario pieno.
- I laboratori producono componenti; non fabbricano piu' nuovi cubi di stanze o dispositivi.
- Sul posto il giocatore seleziona una struttura e ne vede sagoma, costo e componenti disponibili. Il posizionamento non concede una struttura gratuita e non ignora spazio, appoggio o pericoli.
- Se mancano componenti si puo' lasciare un progetto in attesa. Le risorse si consumano una sola volta, quando il giocatore avvia esplicitamente il montaggio.
- Il laboratorio di bordo parte operativo, senza scorte minerali iniziali. I laboratori sotterranei sono officine locali capaci di produrre gli stessi componenti.
- Scale immediate e gratuite da posare e rimuovere; le scale interne della nave restano protette.
- Il jetpack si ricarica quando il personaggio tocca terra. Durata e spinta devono poter essere migliorate in futuro.
- Piu' minerali utili e rari, effettivamente usati nelle ricette.
- Resa del terreno irregolare e continua, senza perdere le unita' metriche precise.

## Proposte di bilanciamento

Le quantita', i nuovi minerali e i dettagli seguenti sono proposte dell'implementatore, non decisioni gia' espresse dal giocatore.

### Componenti e produzione

Due tipi: `electronic_component` e `structural_component`.

| Prodotto | Ingredienti per lotto | Uscita |
| --- | --- | --- |
| Elettronica | 3 rame + 1 cristallo | 2 componenti elettronici |
| Struttura | 4 ferro | 2 componenti strutturali |

Queste due ricette riprendono gli esempi del giocatore. Proposta iniziale: 2 secondi e 0,01 kWh per lotto a livello I, usando il miglioramento di velocita' gia' previsto dai livelli del laboratorio. Quantita' selezionabile, con costi e produzione totali prima della conferma.

Gli ingredienti si pagano atomicamente all'avvio usando il deposito della postazione e il carico realmente accessibile di Robbie. Non si usano depositi remoti. Produzione e quantita' rimanenti persistono; senza alimentazione il lavoro si ferma senza perdere gli ingredienti gia' pagati. La chiusura del menu non cancella la lavorazione.

L'uscita rimane sul banco/deposito locale finche' viene ritirata; se non entra nel deposito non si perde e non viene duplicata. Un comando permette di caricare i componenti pronti senza ripetere un'azione per ogni pezzo. Il menu mostra ingredienti, resa, quantita', tempo totale e progresso.

Si mantiene Robbie come trasportatore, anche per i componenti, senza reintrodurre un inventario personale separato. Nella variante protagonista e' il suo carico diretto. Proposta: 4 componenti dello stesso tipo occupano una unita' di carico, arrotondando per eccesso; un minerale continua a occuparne una. Spostamenti parziali, produzione e pagamenti devono rispettare questo calcolo anche ai confini degli stack.

### Montaggio e progetti

Tasto destro su spazio libero apre il menu di montaggio, non quello di produzione. Il menu del laboratorio conserva una voce distinta per produrre componenti. La sagoma appare solo dopo la scelta di una struttura.

| Struttura | Componenti strutturali | Componenti elettronici |
| --- | --- | --- |
| Laboratorio 4 x 3 m | 4 | 2 |
| Luce | 0 | 1 |
| Pompa acqua | 2 | 2 |
| Ventilatore gas | 1 | 2 |
| Fornace | 3 | 1 |
| Convertitore gas-energia | 2 | 2 |
| Serra | 4 | 2 |

La pompa esistente copre l'esempio del depuratore per questa iterazione: non si introduce un'ottava macchina. Dopo il primo laboratorio si sbloccano i dispositivi come oggi.

Un progetto in attesa e' visibile, non solido, cancellabile gratuitamente e salvato. Il menu contestuale mostra posseduto/richiesto e il pulsante di montaggio. Posseduto significa realmente trasportato dal carico accessibile, non automaticamente disponibile da un laboratorio distante. Sul posto non si consumano minerali grezzi.

Prima di pagare si ricontrollano portata, pareti, spazio scavato, appoggio, sovrapposizioni, pericoli e collegamenti necessari. Avere i componenti non permette di costruire nella roccia, attraverso una parete o in un'area non consentita. Il personaggio puo' occupare una struttura non solida durante il montaggio, come nel laboratorio attuale.

Il montaggio conserva i tempi e il feedback di costruzione esistenti: barra, grafica intermittente, attivazione a fine lavoro. Il progetto non finanziato non consuma energia e non offre servizi. Il pagamento e' unico e il progresso pagato persiste. La rimozione gratuita richiesta vale per le scale, non per il rimborso di macchine gia' costruite.

Riparazioni, upgrade, bombe e infrastrutture vanno controllati per eliminare ogni costo in terra/pietra. Proposta: riparazioni strutturali usano componenti strutturali, servizi elettrici quelli elettronici; le bombe restano munizioni fabbricate al banco, non progetti da montare. I condotti mantengono la posa immediata ma consumano componenti, salvo le scale gratuite. I costi precisi di questi casi sono lasciati all'implementatore, con un unico catalogo condiviso fra logica e UI e senza introdurre altri intermedi.

### Minerali e percorso iniziale

Si mantengono rame e cristalli. Proposta: aggiungere ferro per i componenti strutturali, silice/quarzo per il vetro della fornace al posto della pietra, e cobalto come minerale raro per ricette alternative piu' efficienti o upgrade avanzati. Nessuna ricetta attiva deve richiedere un materiale senza una fonte raggiungibile.

La fornace rimane una strada opzionale di efficienza, non un prerequisito del primo laboratorio o delle strutture base. Proposta concreta: conserva i lingotti di rame, produce vetro dalla silice al posto della pietra e alimenta una ricetta alternativa del laboratorio, 2 lingotti di rame + 1 vetro -> 4 componenti elettronici. Il cobalto ha un uso reale nella ricetta alternativa 2 ferro + 1 cobalto -> 4 componenti strutturali. Queste alternative si sbloccano dopo il primo laboratorio; non aggiungono un terzo tipo di componente da portare in miniera. Le ricette base rimangono sempre disponibili, anche senza gas o acqua per l'industria.

L'estrattore iniziale deve poter raccogliere rame, ferro e il cristallo necessario ai primi componenti. Il primo laboratorio non puo' dipendere da un utensile o una ricetta sbloccati dal laboratorio stesso. I materiali garantiti per il primo laboratorio devono essere accessibili su Ocra senza bombe, laboratori preesistenti sotterranei o scorte iniziali di bordo. Con i costi proposti servono 8 ferro, 3 rame e 1 cristallo: entrano nel carico iniziale.

Robbie insegna la nuova sequenza: scendi, scava e raccogli minerali, torna al banco di bordo, produci i componenti, caricali, scava una stanza 4 x 3 m, posa il progetto e montalo. Non chiede piu' terra/pietra o il trasporto di un cubo. Gli obiettivi restano guidati dai dati ed eventi reali e funzionano con entrambi i protagonisti.

## Jetpack e scale

Proposta di interpretazione: il contatto fisico con un pavimento solido ricarica immediatamente il jetpack al 100%, senza laboratorio o consumo della batteria della nave. Scale, semplice vicinanza a terra e galleggiamento non contano come atterraggio. Il contatto iniziale non deve generare ricarica continua mentre il personaggio decolla. L'immersione continua a disabilitare la spinta.

Durata e potenza diventano parametri distinti; si conserva il comportamento di base di volo gia' esistente. L'acquisto di nuovi livelli di jetpack non e' incluso: si prepara il contratto, senza aggiungere per ora una nuova schermata di upgrade. Ricarica/riparazione di Robbie nei laboratori rimangono separate e non diventano gratuite.

Le scale non richiedono materiale, energia o produzione, sia tramite scorciatoia sia tramite menu. I vincoli di spazio e portata rimangono. Smontarle non restituisce risorse e non permette di accumularle ripetendo posa/rimozione.

## Terreno irregolare

La griglia logica resta 1 cella = 1 metro = 40 pixel del prototipo. Coordinate, collisioni, bersagli, progetti e simulazione delle falde rimangono metrici. Cambia solo la presentazione.

Il renderer deve sostituire il rilievo quadrato ripetuto con masse rocciose continue, facce e fratture irregolari, stratificazione e venature che attraversano piu' celle. I bordi di galleria ricevono piccoli smussi e dettagli rivolti verso la roccia, senza coprire lo spazio utile. Nessun buco visivo nel terreno solido e nessuna roccia apparentemente solida dentro un passaggio percorribile.

La variazione dipende da coordinate e seme: niente tremolio o cambiamenti a ogni fotogramma, zoom o caricamento. Il reticolo completo e' una modalita' diagnostica con G, non una decorazione sempre accesa. Il contorno del bersaglio di scavo resta preciso e comprensibile. Buio, luci e falde continue devono conservare la leggibilita'.

E' una prova della direzione visiva nel renderer 2D attuale, non la produzione definitiva di asset 3D. Dettagli della tessellazione, colori e parametri visivi sono lasciati all'implementatore e vanno valutati con immagini del gioco.

## Salvataggi e limiti

Questa revisione cambia economia e tutorial in modo sostanziale. Proposta per il branch sperimentale: slot di salvataggio separati per l'economia a componenti, ancora distinti fra Umano e Robbie. Le vecchie campagne e i loro cubi restano intatti nei file originali, senza conversioni silenziose o sovrascritture; per la prova si inizia una nuova partita. La migrazione definitiva dei vecchi cubi e delle vecchie scorte non e' inclusa e va concordata prima di pubblicare questa economia come sostituzione finale.

Non si implementano i 12 pianeti, una nuova economia commerciale, dieci intermedi, nuovi specialisti o nuove simulazioni fisiche. Falde, industria, coltivazioni, bombe, manutenzione della nave e scelta del protagonista vanno preservate. Le ricette che usavano terra/pietra devono essere coerenti con le nuove fonti; i cataloghi futuri non vanno presentati come funzionalita' gia' implementate.

## Verifica attesa

- Scavare molto terreno ordinario, anche con carico pieno o Robbie assente, non aumenta il carico e non viene bloccato dalla capienza. I minerali non raccolti non devono sparire: se non entrano rimangono recuperabili.
- Primo laboratorio ottenibile con una partita nuova, senza scorte e senza sblocchi circolari.
- Lotti multipli, stack, uscita piena, pausa per energia, pagamento unico e salvataggio a meta' produzione.
- Progetto in attesa senza oggetti gratis; montaggio valido consuma una sola volta i componenti e riavvio/caricamento non replica il pagamento.
- Vietati montaggi fuori portata, nella roccia, senza supporto, in sovrapposizione o in condizioni pericolose non consentite.
- Scale ripetutamente costruibili/rimuovibili a carico vuoto, senza modificare materiali o energia.
- Jetpack scarico in volo, pieno dopo un vero atterraggio, mai ricaricato da una scala o dal semplice avvicinamento al pavimento.
- Tutorial e interfaccia aggiornati, in entrambe le varianti. Restano test separati per energia delle macchine e manutenzione di Robbie.
- Immagini native a 1280 x 720 e 1920 x 1080 per terreno, sagome, produzione e costruzione. Stessa geometria prima/dopo il cambio di renderer; nessun reticolo regolare involontario o testo sovrapposto.

## Scelte approvate

Il giocatore ha approvato la specifica, comprese le proposte: componenti nel carico di Robbie, stack compatti, costo del primo laboratorio, ricarica istantanea del jetpack e nuova partita in slot separati. Si prepara il piano tecnico e si implementa sul branch corrente, senza commit/push/merge fino alla richiesta del giocatore.
