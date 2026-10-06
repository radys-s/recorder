# Studijní tok: od uložené hodiny k naučené látce

Stav: 2026-10-06. Navazuje na `lib/learning` a `lib/features/study`, žádná
paralelní verze. Bez změny schématu databáze (zůstává v27).

## Co student teď vidí

1. **Hodina → výpisky → kartičky.** Pod výpisky hodiny je skupina „Učení"
   (`LessonStudyPanel`): vytvořit kartičky z těchto výpisků, opakovat z hodiny,
   kvíz před testem, kartičky předmětu. Kartičky vznikají jen z jedné hodiny
   a jen po klepnutí, nikdy hromadně přes všechny nahrávky.
2. **Předmět.** Karta Přehled začíná skupinou „Co teď" s jedním doporučeným
   krokem (`recommendStudyStep`): nahrát první hodinu → vytvořit výpisky →
   udělat kartičky → zopakovat dnešní kartičky → vyzkoušet se před testem.
   Pod ní „Učení" (opakovat, před testem, kartičky). Karta Hodiny je skupina
   „Hodiny a látka"; každý řádek říká, co hodina drží (`lessonStudyLine`):
   výpisky, počet kartiček, kolik jich je dnes na řadě. Hodina s výpisky se
   otevře rovnou na nich.
3. **Opakování, kartičky, kvíz.** Po dokončení opakování i kvízu je výsledek
   a skupina „Co dál" (`NextStepsGroup`) s konkrétními kroky: opakovat teď,
   zopakovat zbytek předmětu, nový kvíz, kartičky předmětu, uložená poznámka.
   Konec opakování říká, kdy přijdou další kartičky (`NextDueLine`).
4. **Opakování jedné hodiny.** `ReviewScreen(meetingId:)` omezí sezení na
   kartičky z jedné hodiny; `StudyCardsDao.dueCards(..., meetingId:)`.
5. **Zdroj a důvěra.** Každá kartička z AI má řádek původu
   (`studyCardProvenance`): „Kartičku vytvořila AI z výpisků hodiny 28. 9. — ověř ji ve výpiscích."
   a v nabídce kartičky „Otevřít zdrojovou hodinu". Texty od AI nejsou
   podávané jako ověřený fakt (`AiDisclaimer` pod panelem a výsledky).

## Kde to je v kódu

| Co | Soubor |
|---|---|
| Doporučení kroku, texty stavů, původ kartičky | `lib/learning/study_flow.dart` |
| „Co dál" a „Další přijde na řadu" | `lib/features/study/study_next_steps.dart` |
| Panel pod výpisky | `lib/features/study/lesson_study_panel.dart` |
| Sekce předmětu | `lib/features/study/study_entry.dart` |
| Dotazy po hodinách | `lib/data/db/daos/study_cards_dao.dart` (`watchLessonStats`, `watchLessonCounts`, `nextDueAfterToday`, `dueCards`) |
| Providery | `lib/features/study/study_providers.dart` (`lessonStudyStatsProvider`, `subjectLessonStudyProvider`, `studyNextDueProvider`) |
| Háček v poznámkách hodiny | `lib/features/meeting_detail/widgets/meeting_notes_tab.dart` (jediný blok `LessonStudyPanel`) |

## Co se nemění

Nahrávky a původní výstupy zůstávají. Žádné hromadné zpracování nahrávek AI,
žádný nový poskytovatel, žádné platby, žádná nová databázová tabulka.

## Ověření

- Testy: `study_flow_test`, `study_lesson_dao_test`, `lesson_study_flow_test`,
  `subject_study_flow_test`, rozšířený `exam_prep_test`.
- `flutter analyze lib test` bez nálezů.
- **Neprovedeno:** ruční ověření na telefonu a pilot. Rozložení na malém iPhonu,
  česká typografie řádků a tok „hodina → kartičky → opakování" ve skutečné
  hodině zůstávají na uživateli.
