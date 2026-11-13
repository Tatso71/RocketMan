# La sagoma e' un ordine completo

Confermato dall'utente il 13 novembre 2026: posare il progetto deve bastare;
piu progetti vengono serviti nell'ordine di posa. Questa decisione sostituisce
il requisito di ordinare manualmente i semilavorati del 12 novembre.

- Nella variante umano, Robbie raccoglie, porta alla nave, fa produrre solo i
  componenti mancanti del primo progetto, li consegna e costruisce.
- Scorte reali e ordini gia pagati, anche manuali, si riusano prima di ordinare
  altri lotti. Nessuna scorta minima automatica e nessun pagamento a distanza.
- La coda dei progetti e' strettamente FIFO. Un primo progetto bloccato ferma
  quelli successivi mostrando il motivo; annullarlo fa avanzare la coda.
- Il computer rimane per controllare stato/scorte e anticipare ordini manuali.
- Costi, ricette, tempi, energia, capienze e accesso fisico restano vincolanti.
- Robbie pilotabile resta manuale. Nessun commit/push/riavvio implicito.
