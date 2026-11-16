# Meteor Dream 0.1.3 – skúška na inext TV5 Ultra

Zostavenie 0.1.3 používa pôvodný secret so zálohou 0.1.2 a aplikuje verzovaný skript tools/meteor_dream_upgrade_013.py. Secret netreba meniť.
Pôvodný podpisový kľúč sa nemení. Aktualizuj 0.1.2 bez odinštalovania.

## Novinky

- Pri BOOT_COMPLETED obnoví povolenie na jeden automatický pokus. Prijímač nespúšťa aplikácie priamo.
- Záznam uvádza boot_count, identifikátor relácie a presný dôvod preskočenia.
- Voliteľná služba prístupnosti Meteor · zastavenie SWEET.TV. Predvolený postup SWEET.TV je vypnutý.
- Zachované krátke podržanie obrazovky pri prechode zo šetriča. Systémový čas 5 minút sa nemení.

## Najprv zachovanie fungujúceho spúšťania

1. Stiahni artefakt Meteor-Dream-APK z posledného úspešného behu, rozbaľ ZIP a nainštaluj Meteor-Dream-0.1.3.apk cez pôvodnú verziu.
2. Raz otvor aplikáciu Meteor šetrič. Voľbu zastavenia SWEET.TV zatiaľ nechaj vypnutú.
3. Over jeden úplný reštart boxu a približne šesť minút bez ovládania. Nestláčaj tlačidlo na nový skúšobný pokus pri overovaní reštartu.
4. Pri preskočení pošli PRIEBEH TESTU; teraz obsahuje konkrétny dôvod.

## Skúška zastavenia SWEET.TV

1. V Meteor šetriči otvor tlačidlom 3 systémovú Prístupnosť.
2. V Službách ručne zapni Meteor · zastavenie SWEET.TV a potvrď systémové upozornenie. AnyDesk netreba zapínať.
3. Vráť sa do Meteor šetriča a použi tlačidlo 4 na jeden ručný test.
4. Sleduj detail SWEET.TV: služba má skúsiť Vynútiť zastavenie a potvrdenie, potom otvoriť Meteor.
5. Až po overení zapni Pred Meteorom skúsiť zastaviť SWEET.TV. Tým povolíš tento postup aj pri automatickom prechode zo šetriča.

Služba ovláda iba systémové nastavenia com.android.tv.settings alebo com.android.settings pri vyžiadanej operácii pre tv.sweet.tvplayer.inext. Prvý klik vyžaduje viditeľnú identifikáciu SWEET.TV a presný názov tlačidla. Potvrdenie skúša iba po tomto kliku. Na neznámom okne nekliká.
Limit jedného pokusu je 20 sekúnd. Pri časovom limite v nastaveniach otvorí Meteor, ale zapíše, že zastavenie nepotvrdila. Ak používateľ odíde z nastavení, zruší kroky bez vynúteného návratu do Meteoru.
Nevypína balík, nemaže dáta, neodinštaluje, nenahrádza root/ADB a nevie garantovať, že operátor SWEET.TV neskôr znovu nespustí.
Úspešný klik alebo neaktívne tlačidlo nie sú priamym meraním RAM/procesov. Výsledok treba potvrdiť na fyzickom boxe.

## Návrat

Vypni prepínač zastavenia v Meteor šetriči. Službu možno úplne vypnúť v Prístupnosti.
Na pôvodný šetrič sa vrátiš výberom Farby v systémových nastaveniach.

## Rozsah

Táto verzia nemení hlavný Meteor IPTV Player ani jeho hlavné menu. Zamedzenie šetriča v hlavnom menu, skrátenie systémového času a reštart boxu zostávajú samostatné otvorené požiadavky.
Zostavenie, podpis a automatické kontroly nenahrádzajú test na zariadení.
