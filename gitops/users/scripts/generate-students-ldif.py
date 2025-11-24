#!/usr/bin/env python3
"""
Generator plików LDIF dla uczniów ZSEL Opole
Generuje pliki class-*.ldif na podstawie list uczniów

Użycie:
    python generate-students-ldif.py --output-dir ../user-ad/students/

Autor: Łukasz Kołodziej
Data: 2025-11-22
"""

import os
import argparse
from typing import List, Dict
import unicodedata


def remove_polish_chars(text: str) -> str:
    """
    Usuwa polskie znaki diakrytyczne i zamienia na ASCII.
    np. 'Łukasz' -> 'Lukasz', 'Zuzanna' -> 'Zuzanna'
    """
    # Mapowanie specjalnych polskich znaków
    polish_map = {
        'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n',
        'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
        'Ą': 'A', 'Ć': 'C', 'Ę': 'E', 'Ł': 'L', 'Ń': 'N',
        'Ó': 'O', 'Ś': 'S', 'Ź': 'Z', 'Ż': 'Z'
    }
    
    result = []
    for char in text:
        if char in polish_map:
            result.append(polish_map[char])
        else:
            result.append(char)
    
    return ''.join(result)


def generate_username(first_name: str, last_name: str) -> str:
    """
    Generuje username w formacie: imie.nazwisko
    Usuwa polskie znaki, zamienia na małe litery
    """
    # Usuń polskie znaki
    first = remove_polish_chars(first_name)
    last = remove_polish_chars(last_name)
    
    # Zamień na małe litery
    first = first.lower()
    last = last.lower()
    
    # Usuń spacje i znaki specjalne (zostaw tylko a-z, cyfry, myślniki)
    first = ''.join(c for c in first if c.isalnum() or c == '-')
    last = ''.join(c for c in last if c.isalnum() or c == '-')
    
    return f"{first}.{last}"


def generate_student_ldif_entry(student: Dict, class_code: str, class_ou: str, specialization: str) -> str:
    """
    Generuje wpis LDIF dla pojedynczego ucznia
    """
    first_name = student['first_name']
    last_name = student['last_name']
    username = generate_username(first_name, last_name)
    
    # Dla imion podwójnych (np. "Wiktor Marek") użyj pełnego imienia w displayName
    display_name = f"{first_name} {last_name} ({class_code})"
    
    ldif_entry = f"""
# Uczeń: {first_name} {last_name}
dn: CN={username},OU={class_ou},OU=Students,DC=ad,DC=zsel,DC=opole,DC=pl
objectClass: user
cn: {username}
sAMAccountName: {username}
givenName: {first_name}
sn: {last_name}
displayName: {display_name}
mail: {username}@student.zsel.opole.pl
userPrincipalName: {username}@ad.zsel.opole.pl
description: Uczeń {class_code} - {specialization}
homeDirectory: \\\\nextcloud.zsel.opole.pl\\home\\students\\{username}
homeDrive: H:
scriptPath: logon-student.bat
userAccountControl: 512
memberOf: CN=Students,OU=Groups,DC=ad,DC=zsel,DC=opole,DC=pl
memberOf: CN={class_ou},OU=Groups,DC=ad,DC=zsel,DC=opole,DC=pl
memberOf: CN=Specialization-{specialization.replace(' ', '-').replace('/', '-')},OU=Groups,DC=ad,DC=zsel,DC=opole,DC=pl
"""
    return ldif_entry


def generate_class_ldif(class_data: Dict, output_dir: str):
    """
    Generuje plik LDIF dla całego oddziału
    """
    class_code = class_data['class_code']
    class_ou = class_data['class_ou']
    specialization = class_data['specialization']
    teacher = class_data['teacher']
    students = class_data['students']
    
    filename = f"class-{class_code.lower()}.ldif"
    filepath = os.path.join(output_dir, filename)
    
    # Nagłówek pliku
    header = f"""# User AD - Oddział {class_code} ({specialization}, {len(students)} uczniów)
# OU: OU={class_ou},OU=Students,DC=ad,DC=zsel,DC=opole,DC=pl
# Wychowawca: {teacher}
# Hasło wspólne dla całego oddziału: {class_code}2025
# Data: 20.11.2025 - RZECZYWISTE DANE

# Organizational Unit: {class_ou}
dn: OU={class_ou},OU=Students,DC=ad,DC=zsel,DC=opole,DC=pl
objectClass: organizationalUnit
ou: {class_ou}
description: Oddział {class_code} - {specialization} (rok 1, {len(students)} uczniów)
"""
    
    # Generuj wpisy dla uczniów
    student_entries = []
    for student in students:
        entry = generate_student_ldif_entry(student, class_code, class_ou, specialization)
        student_entries.append(entry)
    
    # Zapisz do pliku
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(header)
        f.write('\n'.join(student_entries))
    
    print(f"✅ Wygenerowano: {filename} ({len(students)} uczniów)")


def main():
    parser = argparse.ArgumentParser(description='Generator LDIF dla uczniów ZSEL')
    parser.add_argument('--output-dir', default='../user-ad/students/', 
                        help='Katalog docelowy dla plików LDIF')
    args = parser.parse_args()
    
    # Utwórz katalog jeśli nie istnieje
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Dane oddziałów z rzeczywistymi listami uczniów (20.11.2025)
    classes = [
        {
            'class_code': '1AT',
            'class_ou': 'Class-1AT',
            'specialization': 'technik mechatronik',
            'teacher': 'Edyta Kozicka (EK)',
            'students': [
                {'first_name': 'Piotr', 'last_name': 'Adamek'},
                {'first_name': 'Kacper', 'last_name': 'Borek'},
                {'first_name': 'Jan', 'last_name': 'Chlondowski'},
                {'first_name': 'Adam', 'last_name': 'Elias'},
                {'first_name': 'Mikołaj', 'last_name': 'Glizia'},
                {'first_name': 'Szymon', 'last_name': 'Jabcoń'},
                {'first_name': 'Jakub', 'last_name': 'Jabłoński'},
                {'first_name': 'Jan', 'last_name': 'Kaczmarski'},
                {'first_name': 'Jakub', 'last_name': 'Karczewski'},
                {'first_name': 'Bartosz', 'last_name': 'Kołodyński'},
                {'first_name': 'Oliver', 'last_name': 'Kret'},
                {'first_name': 'Bartosz', 'last_name': 'Latała'},
                {'first_name': 'Paweł', 'last_name': 'Lis'},
                {'first_name': 'Oskar', 'last_name': 'Madeła'},
                {'first_name': 'Szymon', 'last_name': 'Mazur'},
                {'first_name': 'Michał', 'last_name': 'Oleś'},
                {'first_name': 'Filip', 'last_name': 'Padamczyk'},
                {'first_name': 'Bartosz', 'last_name': 'Pluta'},
                {'first_name': 'Wiktor Marek', 'last_name': 'Polańczyk'},
                {'first_name': 'Karol', 'last_name': 'Sąsiadek'},
                {'first_name': 'Tomasz', 'last_name': 'Sekula'},
                {'first_name': 'Szymon', 'last_name': 'Sikora'},
                {'first_name': 'Zuzanna', 'last_name': 'Siwińska'},
                {'first_name': 'Aleksander', 'last_name': 'Sklorz'},
                {'first_name': 'Sara', 'last_name': 'Staszczyszyn'},
                {'first_name': 'Mikołaj', 'last_name': 'Szkwarkowski'},
                {'first_name': 'Mateusz', 'last_name': 'Szmit'},
                {'first_name': 'Bartosz', 'last_name': 'Śliwiński'},
                {'first_name': 'Rafał', 'last_name': 'Ślusarczyk'},
                {'first_name': 'Franciszek', 'last_name': 'Ulrich'},
                {'first_name': 'Paweł', 'last_name': 'Ustrzycki'},
            ]
        },
        {
            'class_code': '1BT1',
            'class_ou': 'Class-1BT1',
            'specialization': 'technik elektryk',
            'teacher': 'Magdalena Turek (TU)',
            'students': [
                {'first_name': 'Michał', 'last_name': 'Gabriel'},
                {'first_name': 'Łukasz', 'last_name': 'Garbaczok'},
                {'first_name': 'Franciszek', 'last_name': 'Grzyb'},
                {'first_name': 'Paweł', 'last_name': 'Hadrian'},
                {'first_name': 'Jan', 'last_name': 'Ilków'},
                {'first_name': 'Miłosz', 'last_name': 'Jóśko'},
                {'first_name': 'Filip', 'last_name': 'Junger'},
                {'first_name': 'Jakub', 'last_name': 'Kotynia'},
                {'first_name': 'Julian', 'last_name': 'Kowcun'},
                {'first_name': 'Jan', 'last_name': 'Kucharski'},
                {'first_name': 'Jakub', 'last_name': 'Linkowski'},
                {'first_name': 'Noah', 'last_name': 'Mrachatz'},
                {'first_name': 'Daniel', 'last_name': 'Skiba'},
                {'first_name': 'Krystian', 'last_name': 'Szukała'},
                {'first_name': 'Mateusz', 'last_name': 'Szymkowiak'},
                {'first_name': 'Lech', 'last_name': 'Wojnar'},
                {'first_name': 'Damian', 'last_name': 'Zmarzlik'},
            ]
        },
        {
            'class_code': '1BT2',
            'class_ou': 'Class-1BT2',
            'specialization': 'technik automatyk',
            'teacher': 'Magdalena Turek (TU)',
            'students': [
                {'first_name': 'Dominik', 'last_name': 'Bekiesz'},
                {'first_name': 'Natan', 'last_name': 'Dębowski'},
                {'first_name': 'Maciej', 'last_name': 'Dudek'},
                {'first_name': 'Szymon', 'last_name': 'Hadamek'},
                {'first_name': 'Maksymilian', 'last_name': 'Hartyn Leszczyński'},
                {'first_name': 'Dariusz', 'last_name': 'Ibrahim'},
                {'first_name': 'Jan', 'last_name': 'Lika'},
                {'first_name': 'Kornel', 'last_name': 'Osadzin'},
                {'first_name': 'Wojciech', 'last_name': 'Pietruszka'},
                {'first_name': 'Krzysztof', 'last_name': 'Rother'},
                {'first_name': 'Mateusz', 'last_name': 'Skrzipczyk'},
                {'first_name': 'Michał', 'last_name': 'Stepczuk'},
                {'first_name': 'Dominik', 'last_name': 'Szafranek'},
                {'first_name': 'Miłosz', 'last_name': 'Szczęśniak'},
                {'first_name': 'Tobiasz', 'last_name': 'Szneider'},
                {'first_name': 'Rafał', 'last_name': 'Wrzeciono'},
            ]
        },
        {
            'class_code': '1CT1',
            'class_ou': 'Class-1CT1',
            'specialization': 'technik programista',
            'teacher': 'Piotr Muszyński (Mu)',
            'students': [
                {'first_name': 'Szymon', 'last_name': 'Czapluk'},
                {'first_name': 'Filip', 'last_name': 'Druzgała'},
                {'first_name': 'Dawid', 'last_name': 'Gryc'},
                {'first_name': 'Aleksander', 'last_name': 'Grzelak'},
                {'first_name': 'Oskar', 'last_name': 'Kaźmierowicz'},
                {'first_name': 'Karol', 'last_name': 'Kmiecik'},
                {'first_name': 'Kacper', 'last_name': 'Korczak'},
                {'first_name': 'Marcel', 'last_name': 'Kupczyk'},
                {'first_name': 'Szymon', 'last_name': 'Mientus'},
                {'first_name': 'Dominik', 'last_name': 'Moch'},
                {'first_name': 'Jan', 'last_name': 'Niewiadomski'},
                {'first_name': 'David', 'last_name': 'Radzioch'},
                {'first_name': 'Paweł', 'last_name': 'Wieja'},
                {'first_name': 'Krzysztof', 'last_name': 'Żak'},
            ]
        },
        {
            'class_code': '1CT2',
            'class_ou': 'Class-1CT2',
            'specialization': 'technik teleinformatyk',
            'teacher': 'Piotr Muszyński (Mu)',
            'students': [
                {'first_name': 'Franciszek', 'last_name': 'Cichy'},
                {'first_name': 'Tymoteusz', 'last_name': 'Cieśliński'},
                {'first_name': 'Adam', 'last_name': 'Gaj'},
                {'first_name': 'Ignacy', 'last_name': 'Gaweł'},
                {'first_name': 'Tomasz', 'last_name': 'Górski'},
                {'first_name': 'Jakub', 'last_name': 'Konieczyński'},
                {'first_name': 'Aleksander', 'last_name': 'Macioszek-Kurc'},
                {'first_name': 'Franciszek', 'last_name': 'Majcherczyk'},
                {'first_name': 'Adam', 'last_name': 'Nowicki'},
                {'first_name': 'Michał', 'last_name': 'Raszka'},
                {'first_name': 'Jakob', 'last_name': 'Rudziński'},
                {'first_name': 'Ksawier', 'last_name': 'Serek'},
                {'first_name': 'Tymon', 'last_name': 'Stasiak'},
                {'first_name': 'Szymon', 'last_name': 'Staszowski'},
            ]
        },
        {
            'class_code': '1DT',
            'class_ou': 'Class-1DT',
            'specialization': 'technik informatyk',
            'teacher': 'Joanna Sukiennik (JS)',
            'students': [
                {'first_name': 'Bartosz', 'last_name': 'Anioł'},
                {'first_name': 'Filip', 'last_name': 'Barteczko'},
                {'first_name': 'Konrad', 'last_name': 'Bartków'},
                {'first_name': 'Maksymilian', 'last_name': 'Bisztyga'},
                {'first_name': 'Paweł', 'last_name': 'Bobko'},
                {'first_name': 'Wiktor', 'last_name': 'Buhl'},
                {'first_name': 'Marcin', 'last_name': 'Dworak'},
                {'first_name': 'Michał', 'last_name': 'Firlus'},
                {'first_name': 'Adam', 'last_name': 'Gromada'},
                {'first_name': 'Nikodem', 'last_name': 'Josek'},
                {'first_name': 'Franciszek', 'last_name': 'Judek'},
                {'first_name': 'Julia', 'last_name': 'Kałuża'},
                {'first_name': 'Robert', 'last_name': 'Kempa'},
                {'first_name': 'Aleksander', 'last_name': 'Kowcz'},
                {'first_name': 'Szymon', 'last_name': 'Marciak'},
                {'first_name': 'Grzegorz', 'last_name': 'Młot'},
                {'first_name': 'Dominik', 'last_name': 'Muszkiet'},
                {'first_name': 'Bartosz', 'last_name': 'Napieralski'},
                {'first_name': 'Adam', 'last_name': 'Ozaist'},
                {'first_name': 'Aleksander', 'last_name': 'Pawłowicz'},
                {'first_name': 'Arsenii', 'last_name': 'Protsak'},
                {'first_name': 'Tomasz', 'last_name': 'Romik'},
                {'first_name': 'Jakub', 'last_name': 'Siendzielorz'},
                {'first_name': 'Łukasz', 'last_name': 'Słupczyński'},
                {'first_name': 'Grzegorz', 'last_name': 'Soboń'},
                {'first_name': 'Marcel', 'last_name': 'Sosnowski'},
                {'first_name': 'Nazarii', 'last_name': 'Trach'},
                {'first_name': 'Franciszek', 'last_name': 'Werner'},
                {'first_name': 'Kacper', 'last_name': 'Wolny'},
                {'first_name': 'Stanisław', 'last_name': 'Wójcik'},
            ]
        },
        {
            'class_code': '1AB',
            'class_ou': 'Class-1AB',
            'specialization': 'elektryk',
            'teacher': 'Marek Małecki (MM)',
            'students': [
                {'first_name': 'Alim', 'last_name': 'Ba'},
                {'first_name': 'Mateusz', 'last_name': 'Bartków'},
                {'first_name': 'Miłosz', 'last_name': 'Białas'},
                {'first_name': 'Adam', 'last_name': 'Białecki'},
                {'first_name': 'Franciszek', 'last_name': 'Bil'},
                {'first_name': 'Robert', 'last_name': 'Cebula'},
                {'first_name': 'Jakub', 'last_name': 'Ciuła'},
                {'first_name': 'Maksymilian', 'last_name': 'Cybula'},
                {'first_name': 'Adam', 'last_name': 'Dunat'},
                {'first_name': 'Piotr', 'last_name': 'Dwojak'},
                {'first_name': 'Daniel', 'last_name': 'Fronia'},
                {'first_name': 'Roland', 'last_name': 'Gricman'},
                {'first_name': 'Nataniel', 'last_name': 'Haręza'},
                {'first_name': 'Paweł', 'last_name': 'Herman'},
                {'first_name': 'Michał', 'last_name': 'Jarosz Selepanov'},
                {'first_name': 'Kacper', 'last_name': 'Jenel'},
                {'first_name': 'Wojciech', 'last_name': 'Joszko'},
                {'first_name': 'Filip', 'last_name': 'Klityński'},
                {'first_name': 'Kamil', 'last_name': 'Kudliński'},
                {'first_name': 'Igor', 'last_name': 'Latacz'},
                {'first_name': 'Sebastian', 'last_name': 'Lauer'},
                {'first_name': 'Michał', 'last_name': 'Łoziński'},
                {'first_name': 'Samuel', 'last_name': 'Maciejok'},
                {'first_name': 'Krzysztof', 'last_name': 'Migura'},
                {'first_name': 'Mateusz Grzegorz', 'last_name': 'Mlonka'},
                {'first_name': 'Nicolas', 'last_name': 'Narolski'},
                {'first_name': 'Oliwier', 'last_name': 'Pastuszka'},
                {'first_name': 'Oliwier', 'last_name': 'Prochnij'},
                {'first_name': 'Adam', 'last_name': 'Pyka'},
                {'first_name': 'Marcin', 'last_name': 'Rudkiewicz'},
                {'first_name': 'Mykyta', 'last_name': 'Shylov'},
                {'first_name': 'Maciej', 'last_name': 'Tarnawski'},
                {'first_name': 'Oskar', 'last_name': 'Wiench'},
                {'first_name': 'Marcin', 'last_name': 'Wilczek'},
            ]
        },
        {
            'class_code': '1AW',
            'class_ou': 'Class-1AW',
            'specialization': 'technik elektryk',
            'teacher': 'Wychowawca TBD',
            'students': [
                {'first_name': 'Michał', 'last_name': 'Bałys'},
                {'first_name': 'Jakub', 'last_name': 'Batóg'},
                {'first_name': 'Karol', 'last_name': 'Błażykowski'},
                {'first_name': 'Rafał', 'last_name': 'Błyszcz'},
                {'first_name': 'Łukasz', 'last_name': 'Budzowski'},
                {'first_name': 'Mateusz', 'last_name': 'Dawidowicz'},
                {'first_name': 'Oskar', 'last_name': 'Dzióbek'},
                {'first_name': 'Marek', 'last_name': 'Gąsiorowski'},
                {'first_name': 'Łukasz', 'last_name': 'Gordzielik'},
                {'first_name': 'Leon', 'last_name': 'Kendzierski'},
                {'first_name': 'Filip', 'last_name': 'Konieczny'},
                {'first_name': 'Kajetan', 'last_name': 'Kosno'},
                {'first_name': 'Mateusz', 'last_name': 'Kuc'},
                {'first_name': 'Konrad', 'last_name': 'Mirowski'},
                {'first_name': 'Szymon', 'last_name': 'Nieckarz'},
                {'first_name': 'Jakub', 'last_name': 'Płoskonka'},
                {'first_name': 'Igor', 'last_name': 'Pniewski'},
                {'first_name': 'Damian', 'last_name': 'Rosiński'},
                {'first_name': 'Aleksander', 'last_name': 'Różalski'},
                {'first_name': 'Paweł', 'last_name': 'Rydlakowski'},
                {'first_name': 'Krystian', 'last_name': 'Sura'},
                {'first_name': 'Sebastian', 'last_name': 'Sura'},
                {'first_name': 'Antoni', 'last_name': 'Szpiech'},
                {'first_name': 'Bartłomiej', 'last_name': 'Świder'},
                {'first_name': 'Kacper', 'last_name': 'Ziemniak'},
            ]
        },
    ]
    
    print(f"\n{'='*60}")
    print(f"🚀 Generator LDIF - Uczniowie ZSEL Opole (rok 2025/2026)")
    print(f"{'='*60}\n")
    
    total_students = 0
    for class_data in classes:
        generate_class_ldif(class_data, args.output_dir)
        total_students += len(class_data['students'])
    
    print(f"\n{'='*60}")
    print(f"✅ SUKCES! Wygenerowano {len(classes)} oddziałów ({total_students} uczniów)")
    print(f"{'='*60}\n")
    print(f"📁 Katalog: {os.path.abspath(args.output_dir)}")
    print(f"\n🔐 Hasła:")
    for class_data in classes:
        print(f"   - {class_data['class_code']}: {class_data['class_code']}2025")
    print(f"\n🚀 Następny krok:")
    print(f"   cd ../user-ad/")
    print(f"   ./apply.sh")
    print(f"\n")


if __name__ == '__main__':
    main()
