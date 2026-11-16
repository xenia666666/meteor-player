# Meteor Dream 0.1.4 – potvrdenie zastavenia SWEET.TV na TV boxe

Záznam testu 0.1.3 ukázal prvý klik Vynútiť zastavenie, potom časový limit bez potvrdenia OK. Až po limite sa otvoril Meteor; tento výsledok nepotvrdzoval zastavenie SWEET.TV.

0.1.4 číta aj ďalšie interaktívne okná systémových nastavení, aby mohla overiť titulok SWEET.TV v ľavom paneli a ovládať OK v pravom paneli. Pri presnom párovaní kontroluje text aj contentDescription. Potvrdenie povoľuje iba po vlastnom prvom kliku, pri identifikácii SWEET.TV, výzve zastavenia a dostupných OK a Zrušiť.
Ak po potvrdení zmizne Vynútiť zastavenie, rozpozná návrat do detailu podľa názvu aplikácie a Otvoriť. Nejde o priame meranie procesov alebo RAM.
20-sekundový limit má samostatný časovač; husté udalosti neposúvajú kontrolu donekonečna. Pri časovom limite sa už Meteor automaticky neotvorí cez prípadné nedokončené potvrdenie.
Záznam obsahuje fázu a booleovské údaje o rozpoznaní panelov a tlačidiel, nie texty obrazovky. Bez aktívnej požiadavky služba okná neprechádza.

## Test

1. Aktualizuj Meteor šetrič 0.1.3 na 0.1.4 bez odinštalovania.
2. V systémovej Prístupnosti vypni a znovu zapni Meteor · zastavenie SWEET.TV, aby sa načítala nová konfigurácia služby.
3. V Meteor šetriči stlač 4. Skúsiť zastaviť SWEET.TV a otvoriť Meteor teraz.
4. Prvých 20 sekúnd nestláčaj diaľkač. Sleduj, či sa OK potvrdí samo a potom otvorí Meteor.
5. Ak zostane systémové okno alebo sa postup nedokončí, odfoť PRIEBEH TESTU. Okno môžeš potom potvrdiť alebo zrušiť ručne.

Automatické zastavenie pred Meteorom nechaj vypnuté, kým ručný test neprejde.
Pôvodná 0.1.2 záloha v secrete zostáva zdrojom podpisu; workflow aplikuje tools/meteor_dream_upgrade_014.py. Secret netreba aktualizovať.
Čas šetriča zostáva 5 minút. Táto verzia nemení hlavný prehrávač Meteor ani jeho hlavné menu a neobsahuje systémový reštart boxu.
Zostavenie a podpis sa overujú na GitHub Actions; fyzický test zostáva potrebný.
