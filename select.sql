USE gabinet_dentystyczny;

/* 1 - W�a�ciciel chce zainwestowa� pieni�dze w nowy sprz�t. Chcia�by sprawdzi�, 
na jakie typy us�ug jest najwi�ksze zapotrzebowanie.
Zapytanie: Wypisz 3 najcz�sciej wykonywane us�ugi w 2023 roku,
wraz z ich ilo�ci� oraz ��czn� zarobion� kwot�. */

DROP VIEW OfJoinedUsl; 

CREATE VIEW OfJoinedUsl(Nazwa, Cena)
AS SELECT U.Nazwa, U.Cena
FROM Oferowanie_uslugi AS OU
JOIN Uslugi AS U 
ON U.Nazwa=OU.Nazwa; 

SELECT TOP 3 Nazwa, SUM(Cena) AS Laczna_kwota, COUNT(Cena) AS Ilosc_wykonan FROM OfJoinedUsl 
GROUP BY Nazwa
ORDER BY Ilosc_wykonan DESC;

/* 2 - Wybranie Dentysty kt�ry najbardziej zas�u�y� na podwy�k�
Zapytanie: W�r�d dentyst�w kt�rych wyp�ata w ciagu ostatniego miesiaca (grudnia 2023) 
(kwota wraz z premi�) jest mniejsza ni� �rednia wyp�at w�r�d wszystkich dentyst�w
w bazie danych w ciagu ostatniego miesiaca, znajd� PESEL wraz z iloscia wizyt takiego,
kt�ry mia� najwi�ksz� ilo�� wizyt w ostatnim miesiacu.*/

WITH den_wyp AS (
	SELECT PESEL, COALESCE(Kwota, 0) + COALESCE(Premia, 0) AS Wyplata
	FROM Wyplaty JOIN Dentysci
	ON Wyplaty.PESEL_dentysty = Dentysci.PESEL
	WHERE YEAR(Data)=2023 AND MONTH(Data)=12
)
SELECT TOP 1 PESEL, COUNT(*) AS Ilosc_wizyt FROM Wizyty JOIN den_wyp
ON Wizyty.PESEL_dentysty = den_wyp.PESEL
WHERE Wyplata < (SELECT AVG(Wyplata) FROM den_wyp) AND Odbyla_sie=1 
GROUP BY PESEL
ORDER BY 2 DESC;

/* 3 - Sprawdzenie czy istnieje popyt na wprowadzenie specjalnej oferty dla du�ych rodzin.
Zapytanie: Sprawdzenie ilo�ci pacjent�w kt�rzy s� rodzicami przynajmniej 2 innych pacjent�w
zarejestrowanych w bazie danych kt�rych wiek nie przekracza 18. */

SELECT COUNT(*) AS Ilosc_rodzicow FROM (
	SELECT R.PESEL AS PESEL_rodzica, COUNT(D.PESEL) AS Ilosc_dzieci
	FROM Pacjenci R INNER JOIN Pacjenci D
	ON R.PESEL = D.PESEL_rodzica
	GROUP BY R.PESEL
) AS Podsumowanie;

/* 4 - W�a�ciciel chce nagrodzi� trzech najlepiej sprawuj�cych si� pracownik�w na
podstawie opinii wystawianych przez klient�w.
Zapytanie: Wypisz w porz�dku malej�cym imi�, nazwisko i PESEL i srednia ocene wizyt trzech dentyst�w o najwy�szej
�redniej ocenie wizyty, kt�rzy posiadaj� przynajmniej 5 takich ocen. */

SELECT Osoby.PESEL, Imie, Nazwisko, Srednia_z_ocen FROM (
	SELECT PESEL, AVG(Ocena_wizyty) AS Srednia_z_ocen, COUNT(Ocena_wizyty) AS Ilosc_ocen
	FROM Dentysci JOIN Wizyty
	ON Dentysci.PESEL = Wizyty.PESEL_dentysty
	WHERE Odbyla_sie=1 AND Ocena_wizyty IS NOT NULL
	GROUP BY PESEL
) AS den_oceny JOIN Osoby
ON den_oceny.PESEL = Osoby.PESEL
WHERE Ilosc_ocen >= 5
ORDER BY 4 DESC;

/* 5 - W�a�ciciel rozwa�a wprowadzenie systemu blokuj�cego mo�liwo�� rezerwacji wizyt
klientom, kt�rzy nie przychodz� na umawiane terminy i chce sprawdzi� skal� tego problemu.
Zapytanie: Wypisz PESELE klient�w, kt�rzy w 2024 roku mieli um�wione przynajmniej 3 wizyt,
kt�re si� nie odby�y */

SELECT PESEL_pacjenta FROM (
	SELECT PESEL_pacjenta, COUNT(Odbyla_sie) AS Ilosc_nie_odbytych FROM Wizyty
	WHERE Odbyla_sie=0 AND YEAR(Data)=2024
	GROUP BY PESEL_pacjenta
) AS Odwolujacy
WHERE Ilosc_nie_odbytych >= 3;

/* 6 - Rodzic chce zaprowadzi� dziecko na zabieg. Chce sprawdzi� ulic�,
na kt�rej znajduje si� oddzia�, w kt�rym b�dzie on wykonywany.
Zapytanie: Na kt�r� godzin� i na jakiej ulicy rodzic ma zaprowadzi� swoje dziecko,
kt�rego PESEL to 13060642367 na zabieg um�wiony 11 listopada 2024 roku? */

SELECT Godzina, Ulica, Numer_budynku 
FROM Wizyty JOIN Sale
ON Wizyty.Nr_oddzialu=Sale.Nr_oddzialu 
AND Wizyty.Nr_sali=Sale.Nr_sali 
JOIN Oddzialy
ON Wizyty.Nr_oddzialu = Oddzialy.Nr_oddzialu
WHERE Wizyty.PESEL_pacjenta='13060642367' AND Data='2024-05-03';

/* 7 - Dentysta chce znalezc wolna sale dla pacjenta na umowiony zabieg 
Zapytanie: Wypisz wszystkie wolne sale 06.06.2023r. o godzinie 12:00:00 na zabieg wybielania z�b�w. */

SELECT S.* FROM Sale AS S LEFT JOIN (
SELECT Nr_sali, Nr_oddzialu FROM Uslugi AS U 
JOIN Oferowanie_uslugi AS OU ON U.Nazwa=OU.Nazwa
JOIN Wizyty AS W ON OU.Data=W.Data AND OU.Godzina=W.Godzina
AND OU.PESEL_pacjenta=W.PESEL_pacjenta
WHERE W.Data='2023-06-06'
AND DATEADD(MINUTE, Czas, W.Godzina) > '12:00:00'
AND (DATEADD(MINUTE, (SELECT Czas FROM Uslugi WHERE nazwa='wybielanie z�b�w'), CAST('12:00:00' AS TIME)) > W.Godzina))
AS ZS ON S.Nr_oddzialu=ZS.Nr_oddzialu AND S.Nr_sali=ZS.Nr_sali
WHERE ZS.Nr_sali IS NULL AND ZS.Nr_oddzialu IS NULL;

/* 8 - W�asciciel chce wynagrodzic najdluzej pracujacego pracownika.
Zapytanie: Wypisz PESEL, imie i nazwisko dentysty, kt�ry pracuje do tej pory
i pracuje od najdluzszego czasu */

SELECT TOP 1 Dentysci.PESEL, Imie, Nazwisko 
FROM Dentysci JOIN Osoby
ON Dentysci.PESEL = Osoby.PESEL
WHERE Data_zakonczenia_umowy IS NULL 
ORDER BY Data_zawarcia_umowy ASC









