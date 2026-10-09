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
