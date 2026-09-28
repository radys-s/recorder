// The in-app copy of docs/legal/*.md. `test/legal_texts_test.dart` fails
// when the two drift apart, so edit the Markdown and paste it here.

/// Bump when either text changes in substance: every install is asked to
/// agree again before it can go on.
const kTermsVersion = 1;

/// A legal text: a `## ` line is a heading, a `- ` line a bullet, anything
/// else a paragraph.
class LegalDoc {
  const LegalDoc(this.title, this.body);

  final String title;
  final String body;
}

const kTermsOfUse = LegalDoc('Podmínky použití', r'''
Verze 1 · platí od 28. 9. 2026

## Co aplikace je
- Aftermind nahrává zvuk hodin a schůzek, přepisuje ho na text a pomocí umělé inteligence z něj dělá výpisky, odpovědi, kartičky a kvízy.
- Aplikace se šíří mimo App Store (sideload), je zdarma a poskytuje se „tak, jak je", bez záruky, že bude vždy fungovat bez chyb nebo přerušení.
- Aplikace nemá vlastní server. Všechna data zůstávají na tvém zařízení, kromě toho, co sám pošleš do služeb umělé inteligence nebo na Google Disk (viz Zásady ochrany osobních údajů).

## Nahrávání jiných lidí
- Hlas a projev člověka jsou chráněné zákonem (§ 86 a násl. občanského zákoníku). Nahrávat smíš jen se svolením lidí, kteří jsou na nahrávce slyšet, typicky vyučujícího, pokud zákon výslovně nedovoluje jinak.
- Dodržuj školní řád a pravidla místa, kde nahráváš. Když nahrávání zakazují, nenahrávej.
- Nahrávky, přepisy a výpisky používej pro vlastní studium. Bez souhlasu dotčených lidí je nezveřejňuj a nešiř dál.
- Za to, co a koho nahráváš a jak s nahrávkami naložíš, odpovídáš ty, ne autor aplikace.

## Služby umělé inteligence
- K přepisu a zpracování používáš vlastní klíče ke službám třetích stran (Groq, Google Gemini, Mistral, Cerebras nebo jiná služba, kterou zadáš). Na jejich použití se vztahují jejich vlastní podmínky, limity a případné poplatky.
- Klíč zadáváš jen ty a zůstává uložený v systémovém úložišti klíčů tvého zařízení.

## Výstupy umělé inteligence
- Přepis, výpisky, odpovědi, kartičky a kvízy vytváří umělá inteligence. Mohou obsahovat chyby, vynechávky nebo nepřesnosti.
- Neber je jako jediný nebo zaručený zdroj. Důležité informace si ověř v učebnici, ve zdrojích nebo u vyučujícího.

## Věk
- Aplikaci smíš používat, pokud je ti alespoň 15 let, nebo s předchozím souhlasem zákonného zástupce.

## Odpovědnost
- Autor aplikace neodpovídá za škodu vzniklou jejím používáním, za ztrátu dat ani za výstupy umělé inteligence, a to v rozsahu, který dovoluje zákon.
- Toto omezení se nevztahuje na újmu způsobenou úmyslně nebo z hrubé nedbalosti ani na újmu na přirozených právech člověka.
- Doporučujeme si důležité výpisky pravidelně exportovat nebo sdílet jinam.

## Změny a rozhodné právo
- Když se podmínky změní, aplikace tě při dalším spuštění požádá o nový souhlas.
- Podmínky se řídí právem České republiky.''');

const kPrivacyPolicy = LegalDoc('Zásady ochrany osobních údajů', r'''
Verze 1 · platí od 28. 9. 2026

## Stručně
- Aplikace nemá žádný server, účet ani analytiku. Autor aplikace k tvým nahrávkám, přepisům ani poznámkám nemá přístup.
- Data odcházejí jen do služeb, jejichž klíče sám zadáš, a na Google Disk, pokud zapneš synchronizaci.

## Co je uložené v zařízení
- Zvuk nahrávek. Po dokončení přepisu se maže podle nastavení Místo na disku.
- Přepisy, výpisky, poznámky, kartičky, fotky tabule a stránek, rozvrh, tematický plán a nastavení.
- API klíče a přihlášení ke Googlu, v systémovém úložišti klíčů (Keychain).

## Co odchází a kam
- Groq: úseky zvuku k přepisu a text přepisu, otázek a poznámek k odpovědím a výpiskům.
- Google Gemini (jen s klíčem): fotky, text přepisu a otázek, dohledávání na webu. Pro vylepšený přepis po hodině celá nahrávka hodiny.
- Mistral, Cerebras nebo vlastní služba (jen s klíčem): text přepisu, otázek a poznámek, u Mistralu i fotky, když Gemini nejde.
- Google Disk (jen když synchronizaci zapneš a přihlásíš se): výpisky a volitelně přepisy tvých předmětů.
- Každá z těchto služeb zpracovává data podle svých podmínek. Bezplatné tarify (například Google Gemini a Mistral Experiment) mohou vstupy použít ke zlepšování svých modelů. Podrobnosti a odkazy najdeš v Nastavení u každé služby.

## Údaje ostatních lidí
- Nahrávky obsahují hlasy a projevy vyučujících a spolužáků. Nahrávej je jen s jejich svolením a nepředávej je dál (viz Podmínky použití).
- Do služeb umělé inteligence posílej jen to, co je potřeba ke studiu.

## Jak dlouho
- Data zůstávají v zařízení, dokud je nesmažeš. Zvuk se maže automaticky podle zvolené doby.
- Smazáním aplikace se smaže vše, co je v ní uložené. Kopie u služeb třetích stran se řídí jejich pravidly.

## Tvoje práva
- Export všech dat: Nastavení › Soukromí a data › Exportovat data.
- Smazání všech dat: Nastavení › Soukromí a data › Smazat všechna data.
- Práva vůči službám třetích stran (přístup, výmaz, námitka) uplatňuješ přímo u nich.
- Stížnost můžeš podat u Úřadu pro ochranu osobních údajů (www.uoou.cz).

## Děti
- Pokud ti ještě nebylo 15 let, používej aplikaci jen se souhlasem zákonného zástupce.

## Změny
- Když se zásady změní, aplikace tě při dalším spuštění požádá o nový souhlas.''');

/// Shown under AI output the student may take for fact.
const kAiDisclaimer =
    'AI se může mýlit. Důležité věci si ověř v učebnici nebo u vyučujícího.';
