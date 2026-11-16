# Meteor Dream – zostavenie APK na GitHub Actions

Workflow: Actions → Meteor Dream APK → Run workflow (branch main).
Prvý beh overí Java 17, Android SDK 35 a build-tools 35.0.0.
Ak chýba zdrojový secret, kontrola prostredia môže byť zelená, ale APK ešte nevznikne.

## Jednorazové vloženie súkromnej zálohy

Použi vlastnú zálohu Meteor-Dream-0.1.2-source-private.zip. Obsahuje zdrojový kód a pôvodný podpisový kľúč.
ZIP ani kľúč nenahrávaj do tohto verejného repozitára, issue, release alebo artefaktu.

Na Windows stiahni ZIP do priečinka Downloads a spusti v PowerShelli:

```powershell
$meteorSourcePath = Join-Path $env:USERPROFILE 'Downloads\Meteor-Dream-0.1.2-source-private.zip'
$meteorSourceBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($meteorSourcePath))
if ($meteorSourceBase64.Length -ge 49152) { throw 'ZIP je prilis velky pre GitHub Secret.' }
Set-Clipboard -Value $meteorSourceBase64
```

Týmto sa obsah prevedie na text do schránky. Base64 nie je šifrovanie; text je citlivý rovnako ako ZIP.

V repozitári otvor Settings → Secrets and variables → Actions → New repository secret:

- Name: `METEOR_DREAM_SOURCE_ZIP_BASE64`
- Secret: vlož obsah schránky a ulož.

Potom vyčisti schránku:

```powershell
Set-Clipboard -Value ''
Remove-Variable meteorSourceBase64
```

## Spustenie

Otvor Actions → Meteor Dream APK → Run workflow → main → Run workflow.
Po úspešnom zostavení stiahni artefakt Meteor-Dream-APK a rozbaľ APK.
Kontrola vyžaduje pôvodný certifikát Meteor Dream; nový kľúč nie je akceptovaný.
Zverejňuje sa iba podpísané APK a SHA256SUMS.txt, nikdy súkromná záloha alebo build log.
Artefakt je uchovaný sedem dní. Workflow nevytvára GitHub release a nemení aktualizačné metadáta hlavného Meteoru.

## Ďalšie verzie

Tento prvý postup zostavuje projekt uložený v secrete. Zmeny zdrojového kódu sa musia vložiť ako nová záloha do rovnakého secretu.
Samotná zmena README alebo existujúceho verejného APK tento projekt nezmení.
Dlhodobo je vhodné oddeliť zdrojový kód do súkromného repozitára a ponechať iba podpisový kľúč v samostatných secrets.
Automatické testy a overenie podpisu nenahrádzajú test prehrávania a reštartu na fyzickom boxe.
