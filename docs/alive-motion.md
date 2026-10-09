# Živé animace (M60, část 2)

Navazuje na první část „alive design" (`a86b6a4`). Všechny pohyby berou časy a
křivky z `lib/core/motion.dart` a při omezeném pohybu (`reducedMotion`) hned
ukážou konečný stav, nikdy nezůstanou na nulové průhlednosti.

## Nové widgety (`lib/core/widgets/`)

- `PopIn` – malé „vyskočení" (měřítko + průhlednost, lehký přesah) pro odznak
  po dokončení a ikony správně / špatně.
- `FlipCard` – 3D otočení karty kolem svislé osy. Staví se vždy jen viditelná
  strana, takže čtečka i `find` vidí jednu stranu.
- `StaggerReveal` – postupné odkrytí bloků jedním řadičem (bez časovačů).
  Zpožďuje nejvýš `maxStaggered` bloků, zbytek se odkryje s posledním.
- `TextSkeleton` – šedé řádky se světlým přejezdem místo prázdného pruhu,
  když se generují výpisky. Při omezeném pohybu stojí.

## Kde se používají

- Opakování (`review_screen.dart`): otočení karty, posun další karty, plynulý
  ukazatel postupu, odznak a počty na konci s rozpisem hodnocení.
- Před testem (`exam_prep_screen.dart`): podbarvení možnosti, ikony, vyskočení
  trofeje a počet správných odpovědí.
- Výpisky (`meeting_notes_tab.dart`, `notes_text.dart`): skeleton při
  generování a postupné odkrytí bloků. Odkrývají se jen výpisky mladší než
  3 minuty a jen jednou pro daný obsah, takže otevření staré hodiny je okamžité.

## Testy

`test/alive_motion_test.dart` – obě strany otočení, konečný stav při omezeném
pohybu, jednorázové odkrytí výpisků, `Pressable` nepolyká klepnutí, počítadlo
končí na cíli.

## Dokončení M60 — 2026-10-09

- Knihovna, výsledky hledání a karty předmětu potvrzují změnu dotazu/filtru
  krátkým přechodem nad stejným stromem. `ResultTransition` nevytváří odcházející
  kopii: smazaná položka nezůstává ovladatelná ani ve čtečce. Nové řádky mají
  stabilní klíče a vstup přehrají jen jednou; běžný rebuild není nový vstup.
- Pomocné metody tras používají `AppRoute`: fade a posun 24 px na Androidu a
  desktopu/webu, původní Material/Cupertino přechod na iOS včetně gesta zpět.
  Omezený pohyb ukazuje konečný stav; na iOS zachovává detektor gesta.
- Dlaždice předmětu a záhlaví detailu sdílejí Hero podle ID. Snímek předmětu
  pokrývá pouze první načítací snímek, nepřebíjí pozdější smazání předmětu.
- Primární přidání/uložení, filtry a karty používají stávající `Pressable`.
  Haptika potvrzuje až úspěšný zápis. Návrhy karet se zavírají plynule a jejich
  odcházející řádky mají `IgnorePointer` i `ExcludeSemantics`.
- Uložení návrhu a jeho odebrání tvoří jednu DB transakci; opakované klepnutí
  neotevírá dvě ukládací operace. Chyba zůstává viditelná a umožňuje retry.
- `StaggerReveal` už nevytváří neuklizené `CurvedAnimation` při rebuildu.
  `FlipCard` a `Entrance` dokončí aktuální stav při změně omezení pohybu.
  Skeleton drží jeden controller a zastavuje se při skrytí přes `TickerMode`.
- Regresní test odhalil dvojí hodnocení: druhý rychlý tap po dokončeném zápisu
  mohl hodnotit další neodkrytou kartu. `_grade` nyní vyžaduje odkrytou odpověď.

### Důkazy a hranice

- Dnešní `flutter analyze --no-pub`: bez nálezů. Kompletní cílený běh 14
  souborů: **122 testů prošlo** (motion, hledání, knihovna, předměty, studijní
  tok a příprava na test); nejde o kompletní test suite celého repozitáře.
- Nové `m60_motion_test`, `m60_search_motion_test` a
  `m60_study_interaction_test` pokrývají rychlé změny dotazu, stale completion,
  smazané výsledky, přerušení animace, rebuildy, long-press/scroll, jednu stranu
  kartičky, jeden zápis při dvojím klepnutí, skutečnou trasu předmětu a iOS
  gesto zpět s omezeným pohybem i bez něj. iOS je zde pouze widget test.
- `m60_preview_test`: 12 lokálních syntetických PNG (knihovna, hledání,
  předměty × světlý/tmavý × 320×640/390×844), text 180 %, omezený pohyb.
  Testy neměly layout výjimky; PNG byly vizuálně prohlédnuty. Jde pouze o UI
  důkaz, nikoli mobilní ověření mikrofonu, výkonu nebo skutečné čtečky.
- Po posledním review navíc prošlo 14 cílených testů (včetně přepnutí omezení
  pohybu během vložení návrhu karty). Samostatný snapshot pouze připravovaného
  commitu prošel analýzou a celým cíleným během **49 testů v 7 souborech**.
  Tím je ověřeno, že změny M60 nevyžadují cizí necommitnuté funkce hledání.
- Android debug build přímo v OneDrive dvakrát selhal na Kotlin snapshotu
  `audio_session` (`shrunk-classpath-snapshot.bin: not a regular file`).
  Build totožných zdrojů v oddělené místní složce mimo OneDrive prošel;
  porovnání všech 267 souborů `lib/` a `assets/` neukázalo žádný rozdíl.
  APK: `build/app/outputs/flutter-apk/aftermind-m60-debug.apk`.
  Workspace nadále obsahuje cizí rozpracované hledání, nahrávání, zálohy a
  detail hodiny. Ty nejsou součástí commitu M60; workspace APK je obsahuje.
- Nic nebylo instalováno přes skutečné nahrávky, pushnuto ani publikováno.
  Fyzické zařízení a iOS build nebyly ověřeny. M58 zůstává další fází.
