# Meteor pre iPhone a iPad — 0.1.0 (vývojová verzia)

Natívny SwiftUI projekt pre iOS/iPadOS 17 alebo novší. Nie je to konverzia APK. Schvaľovanie používa existujúci Meteor Panel bez zmien servera.

## Čo je pripravené

- Výber SK/HU/EN, aktivácia cez ID/kód, kontrola stavu a heartbeat v popredí.
- Identita a tajný token v Keychaine; odlišný token od účtu poskytovateľa. Identita sa pri bežnej aktualizácii nemení. Obnovenie po vymazaní zariadenia nie je garantované.
- Zoznamy pridelené Panelom, lokálne Xtream Codes, M3U URL a import M3U súboru. Lokálne prihlásenia sa zobrazujú až po aktivácii.
- Živá TV, filmy, seriály/epizódy, EPG/archív podľa poskytovateľa, rádio zo zoznamu, vyhľadávanie/skupiny a obľúbené.
- AVPlayer: natívne ovládanie, zvuk/titulky dostupné v streame, pomer/vyplnenie/roztiahnutie, skok ±1 min, obnovenie filmu a otázka na ďalšiu epizódu. Automatická obnova po prerušení siete zatiaľ nie je doplnená.
- Panelovému pripojeniu sa neposielajú dáta poskytovateľa. Sieťové odpovede majú limity a chybové správy neobsahujú prihlasovacie URL.

## Dôležité hranice prvej verzie

Toto nie je hotová náhrada všetkých funkcií Androidu. Zatiaľ chýbajú projectM/vizualizácie, rádiový adresár a obaly, integrovaný YouTube/Twitch (odkazy otvoria externú aplikáciu/prehliadač), PIN a skryté skupiny, reklamy/okamžité príkazy z Panela, nahrávanie, sviatočné pozadia, test rýchlosti a prevod/preklad titulkov. `runtime_capable` je zámerne vypnuté, aby Panel nepovažoval tieto príkazy za podporované.

API a prehrávanie vyžadujú HTTPS; HTTP zdroje zatiaľ nie sú podporované.

AVPlayer nepodporuje všetky kontajnery a kodeky Androidu. Živá TV používa HLS `.m3u8`. Archív skúša HLS timeshift, ktorý musí podporovať poskytovateľ. Filmy sa netranskódujú; MKV/AVI a niektoré zvukové stopy môžu byť nedostupné. Fyzické zariadenie a reálne účty ešte treba overiť; automatické testy používajú iba fiktívne údaje.

## Zostavenie bez vlastného Macu

1. Projekt je v samostatnej vetve `ios-meteor-0.1.0` repozitára `xenia666666/meteor-player`. Android Releases sa nemenia.
2. GitHub Actions `Meteor iOS build and tests` sa spustí pri pull requeste; po začlenení aj ručne cez Actions → Run workflow.
3. Workflow na macOS vytvorí projekt, zostaví aplikáciu a spustí XCTest na simulátore iPhonu.
4. Artefakt `Meteor-iOS-SIMULATOR-ONLY` je iba pre simulátor. NIE JE to podpísané IPA pre fyzický iPhone. Nestačí ho otvoriť v mobile.
5. Vo Windowse môžeš prezerať/upravovať zdroj. Lokálny build iOS SDK vyžaduje macOS/Xcode.

Na Macu: z koreňa repozitára `python3 scripts/generate-ios-project.py`, potom otvoriť `ios/Meteor.xcodeproj` a schému `Meteor`.

## Pred prvým TestFlight

- Aktívne Apple Developer členstvo, vlastný tím a App Store Connect záznam s bundle ID `hu.csaladitv.meteor.ios` (alebo schváleným vlastným ID).
- Distribučný podpis a provisioning profile pre tento bundle ID. Android ani Samsung certifikáty sa nepoužívajú.
- Podpisové tajomstvá nastaviť cez GitHub Secrets; nevkladať ich do repozitára, ZIP-u ani logov. Pozri oficiálny návod: https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications .
- Doplniť finálnu 1024×1024 ikonu, overiť súkromie/export compliance a požiadavky poskytovateľa na HTTPS, skutočné streamy a aktiváciu na iPhone/iPade.
- Až potom vytvoriť podpísaný archív a odoslať ho do TestFlight. Tento projekt zatiaľ neobsahuje automatické nahrávanie na App Store.

## Súkromie a transport

Prihlasovacie údaje sa ukladajú v Keychaine, M3U súbory v Application Support so súborovou ochranou iOS. Obľúbené obsahujúce streamové adresy sú v Keychaine, časy pokračovania v miestnych nastaveniach. Appka odosiela identitu/model/verziu/stav prehrávača do existujúceho Panela; verejná IP je prirodzene viditeľná serveru. ATS zostáva bez výnimiek. Prvá verzia prijíma pri prehrávaní aj API iba HTTPS. HTTP adresy nemení automaticky; vyžiadaj HTTPS adresu od poskytovateľa. Panelový bearer token sa neprenáša pri presmerovaní.

Pred publikovaním treba finálne vyhlásenia o súkromí zosúladiť so skutočným prevádzkovateľom Panela a poskytovateľmi. Appka nedodáva kanály ani predplatné.
