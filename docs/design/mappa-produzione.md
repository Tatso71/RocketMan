# Mappa di produzione di RocketMan

Questa e' la mappa del prototipo giocabile: cosa raccogliere, cosa trasformare e cosa costruire. Le proposte future sono separate dalle ricette realmente disponibili.

Documento generato dai cataloghi e dalle funzioni di costo del gioco. Non modificare a mano le tabelle: aggiornare le fonti e rigenerare. [Dati strutturati per la futura guida delle ricette](../../design/generated/production-map.json).

## La catena principale

```text
Materie prime -> Componenti -> Strutture, consumabili e potenziamenti
        |             ^
        +-> Semilavorati (facoltativi) --+
```

**Materie prime:** ferro, rame, cristalli, quarzo e cobalto. **Semilavorati intermedi:** lingotti di rame e vetro. I componenti strutturali ed elettronici sono i semilavorati versatili per il montaggio, impilabili (4 pezzi per unita' di carico). Terra e pietra comuni non entrano nel carico o nelle ricette.

Il laboratorio di bordo e' gia' funzionante e parte senza scorte minerali. Dal 13 novembre nella modalita umano posare una sagoma e' un ordine completo: Robbie raccoglie e scarica alla nave, fa preparare i componenti mancanti del primo progetto, consegna e monta. Nella variante Robbie pilotabile ordini, ritiro e montaggio restano manuali. Il requisito di ordinare prima i semilavorati del 12 novembre e' superato per l'umano. Non si trasportano cubi di stanze gia' scelte. Le scale sono gratuite e immediate.

## Il primo laboratorio

Scava i depositi iniziali di **8 ferro + 3 rame + 1 cristallo**, prepara una stanza supportata di **4 x 3 m** e posa il progetto del laboratorio. Robbie scarica i minerali alla nave e fa preparare solo i componenti mancanti: da scorte vuote, **2 lotti strutturali + 1 elettronico**, ottenendo **4 strutturali + 2 elettronici**. Poi ritira i componenti pronti, li consegna e monta mentre continui a scavare. Non serve tornare al computer per ordinare. Nella variante Robbie pilotabile ordini, ritiri e monti manualmente i componenti.

Dopo il primo laboratorio da campo si sbloccano luci, pompe, ventilatori, fornaci, convertitori, serre e contenitori acqua, oltre alle ricette avanzate dei due componenti. Il contenitore occupa 2 x 2 m, costa 2 componenti strutturali + 1 elettronico e conserva fino a 32 u senza consumo operativo. I consumi della rete si aggiungono all'energia specifica riportata nelle tabelle.

## Ordini e logistica automatica

I progetti seguono una FIFO stretta nell'ordine originale di posa, anche dopo salvataggio/caricamento. Si preparano soltanto i componenti mancanti del primo: si contano prima scorte pronte e uscite gia pagate, comprese quelle di ordini manuali, poi si arrotonda il residuo ai lotti delle ricette esistenti. Nessuna scorta minima o produzione speculativa per progetti successivi. Se il primo e' bloccato, tutta la coda attende e mostra il motivo concreto, per esempio ferro mancante, botola chiusa, uscita piena o energia assente. Non si saltano progetti: sbloccare o annullare il primo fa avanzare la coda.

Clic destro su un laboratorio apre il computer per controllare coda e scorte o anticipare facoltativamente ordini manuali: scegli ricetta e lotti, controlla ingredienti hai/servono, durata ed energia, poi ordina. Gli ordini riservano subito ingredienti ed energia una sola volta e vengono lavorati in sequenza per postazione; laboratori distinti procedono indipendentemente. Questa coda di produzione e' distinta dalla FIFO dei progetti. La coda pagata resta nei salvataggi e si ferma senza energia o con uscita piena, senza perdere materiali.

Nella modalita umano Robbie raccoglie i frammenti e torna fisicamente alla nave quando il carico e' pieno o la raccolta si interrompe brevemente. Ritira i componenti pronti dalla nave o dai laboratori sotterranei, consegna al primo cantiere e resta sul posto durante il montaggio, prima di passare al successivo. Non occorrono ordini di scarico o prelievo. Ricette, costi, tempi, energia, capienze e accesso fisico restano vincolanti. Nella variante Robbie pilotabile ordini, trasporto e montaggio restano manuali.

## Raccolta dalla roccia

I depositi dispersi producono pezzi dello stesso minerale: **1 pezzo nel 65%**, **2 pezzi nel 25%**, **3 pezzi nel 10%** dei casi. I nuovi filoni puri sono regioni irregolari solide e finite: ogni blocco richiede **10 punti di scavo** e rende **12 unita**, rappresentate da un massimo di tre frammenti fisici. La raccolta parziale conserva la quantita restante al suolo e nei salvataggi. Terra e pietra non producono carico.

Su Ocra rame e ferro si trovano subito a sinistra della scala della nave; tre blocchi di cristallo sono presenti poco oltre sullo stesso percorso, oltre ai cristalli a destra. Non serve attraversare una falda o raggiungere il sottosuolo profondo per il primo laboratorio. Questi depositi iniziali restano piu' teneri dei filoni puri.

**Playtest: sacche di gas sospese.** Nei nuovi mondi non c'e' gas naturale, quindi convertitori e fornaci attendono alimentazione. Le serre usano invece la batteria nave tramite il laboratorio operativo locale, con addebito reale; il convertitore collegato resta una fonte alternativa. Le pompe usano la rete del laboratorio; valvole blu e tubi acqua sono gratuiti e non consumano energia.

## Semilavorati

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/copper_ingot.svg" width="24" height="24" alt=""> | Lingotto di rame | Fornace | 2 Rame | 1 Lingotto rame | 12 s | 2.4 Energia locale [kWh] | Fornace collegata a un convertitore gas tramite cavo; ritirare il prodotto. |
| <img src="../../assets/ui/items/glass.svg" width="24" height="24" alt=""> | Vetro | Fornace | 2 Quarzo | 1 Vetro | 10 s | 2 Energia locale [kWh] | Fornace collegata a un convertitore gas tramite cavo; ritirare il prodotto. |

## Componenti e consumabili

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/structural_component.svg" width="24" height="24" alt=""> | Componenti strutturali | Laboratorio di bordo o da campo | 4 Ferro | 2 Componente strutturale | 2 s | 0.01 Energia nave [kWh] | Disponibile dal laboratorio iniziale della nave. |
| <img src="../../assets/ui/items/electronic_component.svg" width="24" height="24" alt=""> | Componenti elettronici | Laboratorio di bordo o da campo | 3 Rame + 1 Cristallo | 2 Componente elettronico | 2 s | 0.01 Energia nave [kWh] | Disponibile dal laboratorio iniziale della nave. |
| <img src="../../assets/ui/items/electronic_component.svg" width="24" height="24" alt=""> | Elettronica da vetro e lingotti | Laboratorio di bordo o da campo | 2 Lingotto rame + 1 Vetro | 4 Componente elettronico | 2 s | 0.01 Energia nave [kWh] | Dopo il primo laboratorio da campo. |
| <img src="../../assets/ui/items/structural_component.svg" width="24" height="24" alt=""> | Strutture in lega di cobalto | Laboratorio di bordo o da campo | 2 Ferro + 1 Cobalto | 4 Componente strutturale | 2 s | 0.01 Energia nave [kWh] | Dopo il primo laboratorio da campo. |
| <img src="../../assets/ui/items/bomb.svg" width="24" height="24" alt=""> | Bomba | Laboratorio di bordo o da campo | 1 Componente strutturale + 1 Componente elettronico | 1 Bomba | 2 s | 0.01 Energia nave [kWh] | Scorte bombe: massimo 4. |

## Montaggio delle strutture

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/laboratory.svg" width="24" height="24" alt=""> | Laboratorio | Sul posto | 4 Componente strutturale + 2 Componente elettronico | 1 Laboratorio | 5 s | 0.3 Energia nave [kWh] | 4 x 3 m; componenti nel carico accessibile. Disponibile dall'inizio. |
| <img src="../../assets/ui/items/lamp.svg" width="24" height="24" alt=""> | Luce | Sul posto | 1 Componente elettronico | 1 Luce | 2.5 s | 0.05 Energia nave [kWh] | 1 x 1 m; componenti nel carico accessibile. Sbloccato dopo il primo laboratorio da campo. |
| <img src="../../assets/ui/items/pump.svg" width="24" height="24" alt=""> | Pompa acqua | Sul posto | 2 Componente strutturale + 2 Componente elettronico | 1 Pompa acqua | 4 s | 0.32 Energia nave [kWh] | 1 x 1 m; componenti nel carico accessibile. Sbloccato dopo il primo laboratorio da campo. |
| <img src="../../assets/ui/items/fan.svg" width="24" height="24" alt=""> | Ventilatore gas | Sul posto | 1 Componente strutturale + 2 Componente elettronico | 1 Ventilatore gas | 4 s | 0.2 Energia nave [kWh] | 2 x 2 m; componenti nel carico accessibile. Sbloccato dopo il primo laboratorio da campo. |
| <img src="../../assets/ui/items/furnace.svg" width="24" height="24" alt=""> | Fornace | Sul posto | 3 Componente strutturale + 1 Componente elettronico | 1 Fornace | 5 s | 0.3 Energia nave [kWh] | 3 x 2 m; componenti nel carico accessibile. Sbloccato dopo il primo laboratorio da campo. |
| <img src="../../assets/ui/items/gas_converter.svg" width="24" height="24" alt=""> | Convertitore gas | Sul posto | 2 Componente strutturale + 2 Componente elettronico | 1 Convertitore gas | 4 s | 0.24 Energia nave [kWh] | 2 x 2 m; componenti nel carico accessibile. Sbloccato dopo il primo laboratorio da campo. |
| <img src="../../assets/ui/items/greenhouse.svg" width="24" height="24" alt=""> | Serra | Sul posto | 4 Componente strutturale + 2 Componente elettronico | 1 Serra | 6 s | 0.36 Energia nave [kWh] | 4 x 3 m; componenti nel carico accessibile. Sbloccato dopo il primo laboratorio da campo. |
| <img src="../../assets/ui/items/water_tank.svg" width="24" height="24" alt=""> | Contenitore acqua | Sul posto | 2 Componente strutturale + 1 Componente elettronico | 1 Contenitore acqua | 4 s | 0.24 Energia nave [kWh] | 2 x 2 m; componenti nel carico accessibile. Sbloccato dopo il primo laboratorio da campo. |

## Scale tubi e cavi

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/ladder.svg" width="24" height="24" alt=""> | Posa scala | Sul posto | Nessuno | 1 Scala | 0 s | Nessuno | Posa e rimozione immediate e gratuite; restano i vincoli geometrici. |
| <img src="../../assets/ui/items/water_conduit.svg" width="24" height="24" alt=""> | Tubo acqua | Sul posto | Nessuno | 1 Tubo acqua | 0 s | Nessuno | Acqua: posa e rimozione gratuite, sullo sfondo senza collisioni; angoli e giunzioni automatici. Un'estremita' libera non versa acqua. |
| <img src="../../assets/ui/items/gas_conduit.svg" width="24" height="24" alt=""> | Tubo gas | Sul posto | 1 Componente strutturale | 1 Tubo gas | 0 s | Nessuno | Costo per segmento di 1 m; posa immediata, non una lavorazione in laboratorio. |
| <img src="../../assets/ui/items/energy_conduit.svg" width="24" height="24" alt=""> | Cavo energia | Sul posto | 1 Componente elettronico | 1 Cavo energia | 0 s | Nessuno | Costo per segmento di 1 m; posa immediata, non una lavorazione in laboratorio. |
| <img src="../../assets/ui/items/valve.svg" width="24" height="24" alt=""> | Monta valvola blu | Dentro una cella di roccia | Nessuno | 1 Valvola blu | 0 s | Nessuno | Gratuita dall'inizio, con acqua in una cella ortogonalmente adiacente. Roccia e acqua restano intatte; quattro facce collegabili, senza tool, perforazione o orientamento. |

## Acqua gas ed energia

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/gas_converter.svg" width="24" height="24" alt=""> | Converti gas in energia locale | Convertitore gas | 1 Gas | 12 Energia locale [kWh] | 25 s | Nessuno | Processo continuo: gas da una falda collegata con tubi; accumulo massimo 12 kWh. Non ricarica automaticamente la nave. |
| <img src="../../assets/ui/items/water.svg" width="24" height="24" alt=""> | Recupera acqua | Pompa acqua | 1 Acqua | 1 Acqua nel serbatoio | 1.429 s | 0.043 Energia nave [kWh] | Pompa 1 x 1 m montata su un tubo terminale o rettilineo, senza pavimento, angoli o giunzioni. On/off e direzione con clic destro. Buffer 8 u, portata massima 0.70 u/s e sollevamento 6 m; consegna soltanto a contenitori, serbatoi nave o serre con spazio. |
| <img src="../../assets/ui/items/water.svg" width="24" height="24" alt=""> | Trasferisci acqua per gravita' | Valvola e contenitore collegati | 1 Acqua | 1 Acqua nel serbatoio | 2.857 s | Nessuno | Portata passiva massima 0.35 u/s, mai sopra il livello della fonte. Solo acqua verso destinazioni finite: contenitore 32 u, serra 4 u, due serbatoi nave da 40 u. Estremita' libere e destinazioni piene non disperdono acqua. |
| <img src="../../assets/ui/items/gas.svg" width="24" height="24" alt=""> | Rimuovi gas pericoloso | Ventilatore gas | 1 Gas | Nessuno | 2.857 s | 0.057 Energia nave [kWh] | Rimuove il gas dall'ambiente: non produce carburante o energia. |

## Coltivazione

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/potato.svg" width="24" height="24" alt=""> | Patata | Serra | 1 Semi di patata + 2 Acqua nel serbatoio | 3 Patata + 2 Semi di patata | 45 s | 0.9 Energia nave [kWh] | Nave: 3 semi di patata iniziali. Acqua dal buffer locale di 4 u; crescita e pioggia soltanto con consumo reale. Energia dal laboratorio operativo piu' vicino entro il suo raggio; in assenza, stessa quantita' dal convertitore collegato via cavi, non entrambe le fonti. |
| <img src="../../assets/ui/items/ochre_tuber.svg" width="24" height="24" alt=""> | Tubero ocra | Serra | 1 Semi di tubero ocra + 2.5 Acqua nel serbatoio | 3 Tubero ocra + 2 Semi di tubero ocra | 50 s | 1 Energia nave [kWh] | Semi trovati nelle capsule dei pianeti. Acqua dal buffer locale di 4 u; crescita e pioggia soltanto con consumo reale. Energia dal laboratorio operativo piu' vicino entro il suo raggio; in assenza, stessa quantita' dal convertitore collegato via cavi, non entrambe le fonti. |
| <img src="../../assets/ui/items/verdant_leaf.svg" width="24" height="24" alt=""> | Verdura viridia | Serra | 1 Semi di verdura viridia + 3 Acqua nel serbatoio | 3 Verdura viridia + 2 Semi di verdura viridia | 40 s | 0.8 Energia nave [kWh] | Semi trovati nelle capsule dei pianeti. Acqua dal buffer locale di 4 u; crescita e pioggia soltanto con consumo reale. Energia dal laboratorio operativo piu' vicino entro il suo raggio; in assenza, stessa quantita' dal convertitore collegato via cavi, non entrambe le fonti. |
| <img src="../../assets/ui/items/frost_berry.svg" width="24" height="24" alt=""> | Bacca brina | Serra | 1 Semi di bacca brina + 1.5 Acqua nel serbatoio | 3 Bacca brina + 2 Semi di bacca brina | 60 s | 1.2 Energia nave [kWh] | Semi trovati nelle capsule dei pianeti. Acqua dal buffer locale di 4 u; crescita e pioggia soltanto con consumo reale. Energia dal laboratorio operativo piu' vicino entro il suo raggio; in assenza, stessa quantita' dal convertitore collegato via cavi, non entrambe le fonti. |

## Potenziamenti

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/module_hull.svg" width="24" height="24" alt=""> | Scafo 1 > 2 | Officina della nave | 4 Componente strutturale + 2 Componente elettronico | 1 Scafo L2 | 0 s | Nessuno | +40 integrita massima per livello |
| <img src="../../assets/ui/items/module_hull.svg" width="24" height="24" alt=""> | Scafo 2 > 3 | Officina della nave | 8 Componente strutturale + 4 Componente elettronico | 1 Scafo L3 | 0 s | Nessuno | +40 integrita massima per livello |
| <img src="../../assets/ui/items/module_engine.svg" width="24" height="24" alt=""> | Propulsori 1 > 2 | Officina della nave | 3 Componente strutturale + 4 Componente elettronico | 1 Propulsori L2 | 0 s | Nessuno | Riduce del 12% il costo delle rotte per livello |
| <img src="../../assets/ui/items/module_engine.svg" width="24" height="24" alt=""> | Propulsori 2 > 3 | Officina della nave | 6 Componente strutturale + 8 Componente elettronico | 1 Propulsori L3 | 0 s | Nessuno | Riduce del 12% il costo delle rotte per livello |
| <img src="../../assets/ui/items/module_cargo.svg" width="24" height="24" alt=""> | Stiva 1 > 2 | Officina della nave | 3 Componente strutturale + 1 Componente elettronico | 1 Stiva L2 | 0 s | Nessuno | +80 unita di carico per livello |
| <img src="../../assets/ui/items/module_cargo.svg" width="24" height="24" alt=""> | Stiva 2 > 3 | Officina della nave | 6 Componente strutturale + 2 Componente elettronico | 1 Stiva L3 | 0 s | Nessuno | +80 unita di carico per livello |
| <img src="../../assets/ui/items/module_battery.svg" width="24" height="24" alt=""> | Accumulatori 1 > 2 | Officina della nave | 1 Componente strutturale + 4 Componente elettronico | 1 Accumulatori L2 | 0 s | Nessuno | +40 kWh di capacita per livello |
| <img src="../../assets/ui/items/module_battery.svg" width="24" height="24" alt=""> | Accumulatori 2 > 3 | Officina della nave | 2 Componente strutturale + 8 Componente elettronico | 1 Accumulatori L3 | 0 s | Nessuno | +40 kWh di capacita per livello |
| <img src="../../assets/ui/items/module_drill.svg" width="24" height="24" alt=""> | Banco strumenti 1 > 2 | Officina della nave | 2 Componente strutturale + 3 Componente elettronico | 1 Banco strumenti L2 | 0 s | Nessuno | +1 potenza per livello. Sblocca Risonatore (II) e Plasma (III). Richiede il primo laboratorio da campo. |
| <img src="../../assets/ui/items/module_drill.svg" width="24" height="24" alt=""> | Banco strumenti 2 > 3 | Officina della nave | 4 Componente strutturale + 6 Componente elettronico | 1 Banco strumenti L3 | 0 s | Nessuno | +1 potenza per livello. Sblocca Risonatore (II) e Plasma (III). Richiede il primo laboratorio da campo. |
| <img src="../../assets/ui/items/module_landing_gear.svg" width="24" height="24" alt=""> | Carrelli 1 > 2 | Officina della nave | 3 Componente strutturale + 1 Componente elettronico | 1 Carrelli L2 | 0 s | Nessuno | Riduce l'usura da atterraggio |
| <img src="../../assets/ui/items/module_landing_gear.svg" width="24" height="24" alt=""> | Carrelli 2 > 3 | Officina della nave | 6 Componente strutturale + 2 Componente elettronico | 1 Carrelli L3 | 0 s | Nessuno | Riduce l'usura da atterraggio |
| <img src="../../assets/ui/items/module_habitat.svg" width="24" height="24" alt=""> | Supporto vitale 1 > 2 | Officina della nave | 2 Componente strutturale + 4 Componente elettronico | 1 Supporto vitale L2 | 0 s | Nessuno | +60 min di riserva nominale e +1 posto equipaggio |
| <img src="../../assets/ui/items/module_habitat.svg" width="24" height="24" alt=""> | Supporto vitale 2 > 3 | Officina della nave | 4 Componente strutturale + 8 Componente elettronico | 1 Supporto vitale L3 | 0 s | Nessuno | +60 min di riserva nominale e +1 posto equipaggio |
| <img src="../../assets/ui/items/module_drone.svg" width="24" height="24" alt=""> | Drone assistente 1 > 2 | Officina della nave | 4 Componente strutturale + 4 Componente elettronico | 1 Drone assistente L2 | 0 s | Nessuno | +8 carico, +0.35 m magnete e +5 m rete impianti per livello; seguito senza limite Richiede il primo laboratorio da campo. |
| <img src="../../assets/ui/items/module_drone.svg" width="24" height="24" alt=""> | Drone assistente 2 > 3 | Officina della nave | 8 Componente strutturale + 8 Componente elettronico | 1 Drone assistente L3 | 0 s | Nessuno | +8 carico, +0.35 m magnete e +5 m rete impianti per livello; seguito senza limite Richiede il primo laboratorio da campo. |
| <img src="../../assets/ui/items/laboratory.svg" width="24" height="24" alt=""> | Laboratorio 1 > 2 | Laboratorio di bordo o da campo | 4 Componente strutturale + 2 Componente elettronico | 1 Laboratorio L2 | 0 s | Nessuno | Potenzia la singola postazione. Il laboratorio di bordo richiede prima il primo laboratorio da campo. |
| <img src="../../assets/ui/items/laboratory.svg" width="24" height="24" alt=""> | Laboratorio 2 > 3 | Laboratorio di bordo o da campo | 8 Componente strutturale + 4 Componente elettronico | 1 Laboratorio L3 | 0 s | Nessuno | Potenzia la singola postazione. Il laboratorio di bordo richiede prima il primo laboratorio da campo. |

## Riparazioni

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/laboratory.svg" width="24" height="24" alt=""> | Ripara Laboratorio | Installazione danneggiata | 2 Componente strutturale + 1 Componente elettronico | 1 Ripristino: Laboratorio | 0 s | Nessuno | Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente. |
| <img src="../../assets/ui/items/lamp.svg" width="24" height="24" alt=""> | Ripara Luce | Installazione danneggiata | 1 Componente elettronico | 1 Ripristino: Luce | 0 s | Nessuno | Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente. |
| <img src="../../assets/ui/items/pump.svg" width="24" height="24" alt=""> | Ripara Pompa acqua | Installazione danneggiata | 1 Componente strutturale + 1 Componente elettronico | 1 Ripristino: Pompa acqua | 0 s | Nessuno | Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente. |
| <img src="../../assets/ui/items/fan.svg" width="24" height="24" alt=""> | Ripara Ventilatore gas | Installazione danneggiata | 1 Componente strutturale + 1 Componente elettronico | 1 Ripristino: Ventilatore gas | 0 s | Nessuno | Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente. |
| <img src="../../assets/ui/items/furnace.svg" width="24" height="24" alt=""> | Ripara Fornace | Installazione danneggiata | 2 Componente strutturale + 1 Componente elettronico | 1 Ripristino: Fornace | 0 s | Nessuno | Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente. |
| <img src="../../assets/ui/items/gas_converter.svg" width="24" height="24" alt=""> | Ripara Convertitore gas | Installazione danneggiata | 1 Componente strutturale + 1 Componente elettronico | 1 Ripristino: Convertitore gas | 0 s | Nessuno | Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente. |
| <img src="../../assets/ui/items/greenhouse.svg" width="24" height="24" alt=""> | Ripara Serra | Installazione danneggiata | 2 Componente strutturale + 1 Componente elettronico | 1 Ripristino: Serra | 0 s | Nessuno | Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente. |
| <img src="../../assets/ui/items/water_tank.svg" width="24" height="24" alt=""> | Ripara Contenitore acqua | Installazione danneggiata | 1 Componente strutturale + 1 Componente elettronico | 1 Ripristino: Contenitore acqua | 0 s | Nessuno | Costo: meta' del montaggio, arrotondata per eccesso per ciascun componente. |
| <img src="../../assets/ui/items/module_hull.svg" width="24" height="24" alt=""> | Ripara scafo | Officina della nave | 2 Componente strutturale + 1 Componente elettronico | 25 Integrita' scafo | 0 s | Nessuno | Il recupero e' limitato dall'integrita' massima. |
| <img src="../../assets/ui/items/laboratory.svg" width="24" height="24" alt=""> | Ripara officina di bordo | Officina danneggiata | 3 Componente strutturale + 1 Componente elettronico | 1 Officina di bordo riparata | 0 s | Nessuno |  |

## Servizi provvisori della nave

| Icona | Operazione | Dove | Ingredienti | Risultato | Tempo base | Energia | Condizioni |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <img src="../../assets/ui/items/ship_fuel.svg" width="24" height="24" alt=""> | Rifornisci nave | Officina della nave | 1 Componente elettronico | 20 Carburante nave | 0 s | Nessuno | Ricetta provvisoria del prototipo: il petrolio non viene ancora usato per il carburante. |
| <img src="../../assets/ui/items/module_battery.svg" width="24" height="24" alt=""> | Ricarica batteria nave | Officina della nave | Nessuno | 15 Energia nave [kWh] | 0 s | Nessuno | Servizio provvisorio senza ingredienti; non e' ancora una filiera energetica definitiva. |

## A cosa serve ogni materiale

Indice inverso: le tabelle sopra contengono i costi; questo elenco indica dove viene utilizzata ogni risorsa.

- <img src="../../assets/ui/items/copper.svg" width="24" height="24" alt=""> **Rame:** Lingotto di rame; Componenti elettronici.
- <img src="../../assets/ui/items/gas_converter.svg" width="24" height="24" alt=""> **Energia locale [kWh]:** Lingotto di rame; Vetro.
- <img src="../../assets/ui/items/silica.svg" width="24" height="24" alt=""> **Quarzo:** Vetro.
- <img src="../../assets/ui/items/iron.svg" width="24" height="24" alt=""> **Ferro:** Componenti strutturali; Strutture in lega di cobalto.
- <img src="../../assets/ui/items/module_battery.svg" width="24" height="24" alt=""> **Energia nave [kWh]:** Componenti strutturali; Componenti elettronici; Elettronica da vetro e lingotti; Strutture in lega di cobalto; Bomba; Laboratorio; Luce; Pompa acqua; Ventilatore gas; Fornace; Convertitore gas; Serra; Contenitore acqua; Recupera acqua; Rimuovi gas pericoloso; Patata; Tubero ocra; Verdura viridia; Bacca brina.
- <img src="../../assets/ui/items/crystal.svg" width="24" height="24" alt=""> **Cristallo:** Componenti elettronici.
- <img src="../../assets/ui/items/copper_ingot.svg" width="24" height="24" alt=""> **Lingotto rame:** Elettronica da vetro e lingotti.
- <img src="../../assets/ui/items/glass.svg" width="24" height="24" alt=""> **Vetro:** Elettronica da vetro e lingotti.
- <img src="../../assets/ui/items/cobalt.svg" width="24" height="24" alt=""> **Cobalto:** Strutture in lega di cobalto.
- <img src="../../assets/ui/items/structural_component.svg" width="24" height="24" alt=""> **Componente strutturale:** Bomba; Laboratorio; Ripara Laboratorio; Pompa acqua; Ripara Pompa acqua; Ventilatore gas; Ripara Ventilatore gas; Fornace; Ripara Fornace; Convertitore gas; Ripara Convertitore gas; Serra; Ripara Serra; Contenitore acqua; Ripara Contenitore acqua; Tubo gas; Scafo 1 > 2; Scafo 2 > 3; Propulsori 1 > 2; Propulsori 2 > 3; Stiva 1 > 2; Stiva 2 > 3; Accumulatori 1 > 2; Accumulatori 2 > 3; Banco strumenti 1 > 2; Banco strumenti 2 > 3; Carrelli 1 > 2; Carrelli 2 > 3; Supporto vitale 1 > 2; Supporto vitale 2 > 3; Drone assistente 1 > 2; Drone assistente 2 > 3; Laboratorio 1 > 2; Laboratorio 2 > 3; Ripara scafo; Ripara officina di bordo.
- <img src="../../assets/ui/items/electronic_component.svg" width="24" height="24" alt=""> **Componente elettronico:** Bomba; Laboratorio; Ripara Laboratorio; Luce; Ripara Luce; Pompa acqua; Ripara Pompa acqua; Ventilatore gas; Ripara Ventilatore gas; Fornace; Ripara Fornace; Convertitore gas; Ripara Convertitore gas; Serra; Ripara Serra; Contenitore acqua; Ripara Contenitore acqua; Cavo energia; Scafo 1 > 2; Scafo 2 > 3; Propulsori 1 > 2; Propulsori 2 > 3; Stiva 1 > 2; Stiva 2 > 3; Accumulatori 1 > 2; Accumulatori 2 > 3; Banco strumenti 1 > 2; Banco strumenti 2 > 3; Carrelli 1 > 2; Carrelli 2 > 3; Supporto vitale 1 > 2; Supporto vitale 2 > 3; Drone assistente 1 > 2; Drone assistente 2 > 3; Laboratorio 1 > 2; Laboratorio 2 > 3; Ripara scafo; Rifornisci nave; Ripara officina di bordo.
- <img src="../../assets/ui/items/gas.svg" width="24" height="24" alt=""> **Gas:** Converti gas in energia locale; Rimuovi gas pericoloso.
- <img src="../../assets/ui/items/water.svg" width="24" height="24" alt=""> **Acqua:** Recupera acqua; Trasferisci acqua per gravita'.
- <img src="../../assets/ui/items/seed_potato.svg" width="24" height="24" alt=""> **Semi di patata:** Patata.
- <img src="../../assets/ui/items/water.svg" width="24" height="24" alt=""> **Acqua nel serbatoio:** Patata; Tubero ocra; Verdura viridia; Bacca brina.
- <img src="../../assets/ui/items/seed_ochre_tuber.svg" width="24" height="24" alt=""> **Semi di tubero ocra:** Tubero ocra.
- <img src="../../assets/ui/items/seed_verdant_leaf.svg" width="24" height="24" alt=""> **Semi di verdura viridia:** Verdura viridia.
- <img src="../../assets/ui/items/seed_frost_berry.svg" width="24" height="24" alt=""> **Semi di bacca brina:** Bacca brina.

## Vincoli importanti

- Il tempo dei lotti e' riferito a un laboratorio L1; i livelli superiori accelerano la produzione. Ingredienti ed energia del lotto si pagano all'avvio; output e avanzamento non si perdono chiudendo il menu.
- Il montaggio consuma i componenti reali consegnati sul posto. Il totale informativo del deposito non e' un pagamento a distanza. Robbie deve raggiungere fisicamente il cantiere e rimanere presente durante il proprio lavoro; sicurezza ed energia restano obbligatorie. Le strutture richiedono pavimento, tranne le pompe montate su tubi.
- La fornace usa energia locale del convertitore, non direttamente la batteria della nave. La serra usa il laboratorio operativo locale, oppure il convertitore via cavo: si addebita la fonte effettiva. Il buffer della serra contiene fino a 4 u; pioggia e crescita richiedono acqua realmente consumata.
- I contenitori conservano fino a 32 u e non richiedono energia operativa. I due serbatoi acqua della nave hanno porte blu permanenti, capienza di 40 u ciascuno e conservano l'acqua durante viaggi e salvataggi. Togliere un tubo interrompe il flusso senza perdere acqua; non esistono scarichi liberi.
- Il laboratorio e i dispositivi alimentati dalla nave continuano a consumare durante l'uso: l'energia di montaggio non e' il loro intero costo di vita.
- Le riparazioni elencate sono riparazioni di installazioni/scafo. La manutenzione di tuta e Robbie e il riposo non sono nuove ricette di costruzione.

## Da progettare o completare

- **Fabbricazione dei singoli tool:** Ricette e costi da definire. Pulse, Scanner e Jetpack sono iniziali; Risonatore e Plasma si ottengono dal Banco strumenti.
- **Potenziamenti acquistabili dello scanner:** Proposta approvata: raggi 4/5/6/7 m e tracce solo sull'onda / 3 / 7 / 12 s. Acquisto e nuova curva non ancora implementati: oggi la persistenza e' 2 + 0.7 s per livello.
- **Lavorazione del petrolio:** Petrolio e acido sono pericoli fisici, non ingredienti di ricette attuali. Nessun costo futuro inventato.
- **Enciclopedia del computer di bordo:** Usare gli stessi dati generati per cercare ingredienti, prodotti, stazioni, sblocchi e impieghi. La schermata nel gioco non esiste ancora.
- **Miscele e altri fluidi trasportati:** Il circuito attuale trasporta solo acqua. Miscele, reazioni e trasporto di gas, petrolio o acido nei serbatoi restano futuri; nessuna conversione implicita.
- **Pavimenti e volumi costruibili:** Possibilita' di creare appoggi e passaggi dopo scavi estesi; decisioni rinviate dal giocatore.
- **Fabbricazione di altri Robbie:** Futura squadra con incarichi e carichi separati. Il ciclo automatico attuale usa solo Robbie assistente dell'umano; costi, sblocchi e ricette degli ulteriori robot non sono ancora definiti.
- **Filtri per purificare l'acqua:** Fondamentali per le coltivazioni: le serre richiederanno acqua adatta all'irrigazione, non soltanto una quantita' disponibile; l'acqua contaminata dovra' essere filtrata. Modulo separato dalla pompa e collegato ai tubi prima dell'utilizzo o dello stoccaggio. Contaminanti, soglie di qualita', ricette, consumi e manutenzione da definire; nessuna purificazione attiva nel runtime attuale.

## Come tenere aggiornata la mappa

```powershell
godot --headless --path . -s res://tools/design/build-production-map.gd
godot --headless --path . -s res://tools/design/build-production-map.gd -- --check
```

Il comando genera questo documento e il JSON della mappa. `--check` fallisce se uno dei due e' assente o non aggiornato. Le fonti sono `prototype_components.json`, `prototype_industry.json`, i cataloghi dei moduli e i metodi di costo di strutture, nave, condotti e riparazioni. Le proposte e le note editoriali si aggiornano nel generatore.

**Computer di bordo, prossimo passo:** ricerca per nome; viste 'come si produce' e 'a cosa serve'; catena degli ingredienti; stazioni richieste; materiali posseduti/mancanti. Il documento di sviluppo mostra tutto, ma la futura vista del giocatore dovra' distinguere ricette note, sbloccate e ancora da scoprire.
