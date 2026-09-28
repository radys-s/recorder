# Zásady ochrany osobních údajů

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
- Když se zásady změní, aplikace tě při dalším spuštění požádá o nový souhlas.
