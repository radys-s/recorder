# Aftermind

**AI asistent do školy, který nahrává hodinu, rozumí jí a pomůže ti látku naučit.**

Aftermind je mobilní aplikace (Flutter, primárně iPhone) pro studenty. Položíš
telefon na lavici, spustíš nahrávání a o zbytek se postará: průběžně přepisuje
řeč, během hodiny odpovídá na otázky, po hodině udělá výpisky do sešitu
a z nich kartičky na opakování a kvíz před testem.

Aplikace je česky a bez vlastního serveru. Všechna data zůstávají v telefonu
a AI služby si student připojuje **vlastními API klíči** (BYOK).

## Co umí

### Před hodinou
- **Předměty** s barvou, vlastními pravidly pro AI, rozvrhem a tematickým plánem.
- **Rozvrh ze screenshotu** – vyfotíš nebo nahraješ rozvrh a AI z něj vytvoří předměty
  a hodiny. Aplikace podle času sama navrhne předmět a připomene začátek hodiny.
- **Karty s kontextem** (kniha, téma, pojmy) – psané, z fotky stránky (OCR) nebo
  „dohledané" AI s odkazy na zdroje. AI je používá při odpovídání i při přepisu.
- **Tematický plán** z vloženého textu, fotky nebo odhadu AI; aplikace pozná,
  které téma se právě probírá.

### Během hodiny
- **Nahrávání** s ochranou před ztrátou: hlídač výpadku mikrofonu, záloha rozpracovaného
  zvuku každých 5 s, kontrola místa, upozornění na slabý signál nebo tichý mikrofon.
  Běží na pozadí i při zamčené obrazovce.
- **Živý přepis** po úsecích (dělených na pauzách v řeči), s automatickou citlivostí,
  korekcí podle slovníku předmětu a hlídáním vymyšleného textu.
- **Živé odpovědi** – když se v hodině zeptají, aplikace odpoví krátkým řádkem
  s rozbalitelným vysvětlením (z hodiny, z karty, ze znalostí AI nebo z webu
  s odkazy na zdroje). Hovory o ničem se ignorují.
- **Chat** přímo u přepisu: dodáš kontext, pravidlo („odpovídej jednou větou")
  nebo se zeptáš. Foťák na tabuli a slidy, tlačítko „Odpověz teď", hvězdička ⭐
  pro důležité místo.
- **Fotka s otázkami** – otázky na fotce se vytáhnou a zodpoví.

### Po hodině
- **Vylepšený přepis** dlouhými okny (Gemini, jinak Whisper) – oprava toho, co živý
  přepis zkomolil. Opravu slova v přepisu si aplikace zapamatuje pro celý předmět.
- **Výpisky do sešitu** v pěti hloubkách od heslovitých po kompletní: téma, klíčové pojmy,
  příklady, souvislosti, co si zapamatovat. Vznikají až po skončení hodiny.
- **Učení**: kartičky s rozloženým opakováním (SM-2), „Dnes zopakovat",
  režim **Před testem** (shrnutí + kvíz z vybraných témat), doporučený další krok
  u předmětu.
- **Přehled předmětu** – co plán pokrývá, co se probralo a co chybí, shrnutí celého předmětu.
- **Hledání** napříč hodinami, přepisy, výpisky, kartami i chatem (bez ohledu
  na diakritiku a velikost písmen).
- **Sdílení a sync**: sdílení výpisků a přepisu, volitelné Google Docs pro NotebookLM.
- Přehrání původní nahrávky, **záloha a obnova** (`tool/restore_backup.dart`).

## Jak to funguje

```
mikrofon ─▶ filtr 80 Hz ─▶ dělení na pauzách + automatický zisk ─▶ WAV na disku
                                                                      │
              fronta nahrávek (drift) ◀───────────────────────────────┘
                     │  Groq Whisper ▸ Whisper turbo ▸ Gemini audio
                     ▼
        průběžný přepis ─▶ oprava podle slovníku ─▶ živé odpovědi + chat
                     │
                     └─ po hodině: vylepšený přepis ─▶ výpisky ─▶ kartičky, kvíz
```

- **Nahrávání je oddělené od sítě.** Hotový úsek se hned uloží a zařadí do fronty;
  přepis čeká, dokud nepřijde síť nebo klíč, a limity (HTTP 429) frontu jen
  pozdrží, nespotřebují pokusy.
- **AI router** zkouší služby, které mají klíč, a při limitu nebo přetížení
  přejde na další. Gemini jde první tam, kde se hodí (dlouhý kontext, fotky);
  Groq, Mistral, Cerebras a vlastní služba se střídají podle velikosti úlohy.
  Stav služeb je vidět v Nastavení.
- **Kontext pod rozpočtem tokenů** – pravidla, připnuté karty, kontext od studenta
  a konec přepisu se skládají tak, aby se vešly do limitu dané služby.

## AI služby a klíče

Klíče zadáváš v **Nastavení** na telefonu a ukládají se do Keychainu. Do repozitáře
ani do chatu je nikdy nevkládej.

| Služba | K čemu | Povinná |
| --- | --- | --- |
| Groq | přepis (Whisper), rychlé odpovědi | jeden z přepisových klíčů |
| Google Gemini | dlouhý kontext, fotky, vyhledávání, přepis zvuku | doporučená |
| Mistral, Cerebras | záloha při limitu | volitelné |
| Vlastní (OpenAI‑kompatibilní) | např. školní model | volitelné |

Aplikace neposílá nic bez klíče. Co se kam odesílá, ukazuje u každé služby
tlačítko „Co se posílá a podmínky služby".

## Soukromí a právo

- Žádný účet, žádný server, žádná telemetrie; databáze a zvuk jsou jen v telefonu.
- Před prvním použitím je nutné odsouhlasit podmínky a zásady ochrany údajů
  (`docs/legal/`). Před nahráváním se zobrazí upozornění, že **nahrávat lze jen
  se souhlasem nahrávaných a v souladu s pravidly školy** (§ 86 občanského zákoníku).
- Nastavení → *Soukromí a data*: export dat a smazání všeho (databáze, zvuk, fotky, klíče).
- Právní texty jsou koncept; před veřejným nebo placeným vydáním je má zkontrolovat právník.

## Technologie

Flutter 3.47.2 · Dart 3.13 · Riverpod · drift (SQLite, schéma v27) · Dio · `record`
(PCM 16 kHz) · `just_audio` · `flutter_secure_storage` · `flutter_local_notifications`.
UI má vlastní motion systém (`lib/core/motion.dart`), respektuje omezený pohyb
a nabízí čtyři barevné akcenty.

```
lib/
  ai/        router, poskytovatelé (Groq, Gemini, OpenAI‑kompatibilní), odpovědi, výpisky
  audio/     nahrávání, dělení na úseky, zisk, zotavení po výpadku
  stt/       přepis, slovník, filtry vymyšleného textu
  queue/     fronta přepisu a vylepšený přepis
  learning/  kartičky, plánovač opakování, příprava na test
  data/      drift databáze, DAO, zálohy
  features/  obrazovky (nahrávky, předměty, poznámky, studium, nastavení…)
  sync/      Google Disk / Docs
  preview/   webová ukázka s demo daty pro testování UI
```

## Vývoj

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift
flutter analyze
flutter test
flutter run
```

**Webová ukázka (jen pro testování UI, bez mikrofonu a sítě):**

```bash
flutter build web -t lib/preview/main_web_preview.dart
```

Scénář se vybírá parametrem `?scenario=fresh|full|recording`.

> iOS se lokálně na Windows nesestaví. IPA vzniká jen v CI.

## iOS build a instalace

GitHub Actions (`.github/workflows/ios.yml`, macOS runner, Flutter 3.47.2) spustí analýzu
a testy a postaví **nepodepsané** IPA (`Aftermind-iOS-…` artefakt). Podepisuje se
až na telefonu vlastním Apple ID – např. přes iloader nebo SideStore. Bez placeného
vývojářského účtu platí podpis 7 dní a pak je potřeba IPA znovu nainstalovat
(data zůstávají, ukládají se relativní cesty).

```bash
gh run list --workflow "iOS build" --limit 3
gh run download <run-id> -n Aftermind-iOS-1.0.0-build3
```

## Dokumentace

- `docs/study-flow.md` – studijní tok od hodiny po naučenou látku
- `docs/alive-motion.md` – živé animace a pravidla pro omezený pohyb
- `docs/pilot-quality-pass.md` – kontrola kvality pilotní verze
- `docs/local-search.md` – hledání hodin a témat
- `docs/legal/` – podmínky použití a zásady ochrany osobních údajů

## Stav

Verze 1.0.0 (beta, build 3). Funguje na iPhonu, ale nemá veřejné vydání.
Kvalita přepisu v reálné třídě a chování mikrofonu při hovorech a změně
zvukové trasy se ověřují jen na zařízení.
