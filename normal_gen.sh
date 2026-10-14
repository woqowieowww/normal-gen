#!/bin/bash

LANG=C
SCRIPT_NAME="$(basename "$0")"
CONFIG_FILE="$HOME/.normal_gen.conf"

COUNT=100
MU=0.0
SIGMA=1.0
SEED=""
METHOD=1
METHOD_NAMES=("Бокса-Мюллера" "Неймана" "Марсальи-Брея")
NUMBERS=()

is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]
}

is_number() {
    [[ "$1" =~ ^-?[0-9]*\.?[0-9]+$ ]]
}

prompt_number() {
    local prompt="$1" var_name="$2" is_positive="$3" allow_float="$4"
    local value
    while true; do
        read -p "$prompt" value
        if [[ -z "$value" ]]; then
            echo "Ошибка: ввод не может быть пустым." >&2
            continue
        fi
        if [[ "$allow_float" == "yes" ]]; then
            if ! is_number "$value"; then
                echo "Ошибка: введите число." >&2
                continue
            fi
        else
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                echo "Ошибка: введите целое неотрицательное число." >&2
                continue
            fi
        fi
        if [[ "$is_positive" == "yes" ]]; then
            if [[ "$allow_float" == "yes" ]]; then
                if (( $(echo "$value <= 0" | bc -l) )); then
                    echo "Ошибка: значение должно быть положительным." >&2
                    continue
                fi
            else
                if [[ "$value" -le 0 ]]; then
                    echo "Ошибка: значение должно быть положительным." >&2
                    continue
                fi
            fi
        fi
        eval "$var_name=\"$value\""
        break
    done
}

box_muller() {
    local count=$1 mu=$2 sigma=$3 seed=$4
    awk -v count="$count" -v mu="$mu" -v sigma="$sigma" -v seed="$seed" '
    BEGIN {
        if (seed != "") srand(seed); else srand();
        pi = 4 * atan2(1, 1);
        for (i = 1; i <= count; i += 2) {
            u1 = rand(); if (u1 == 0) u1 = 1e-10;
            u2 = rand();
            z0 = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
            z1 = sqrt(-2 * log(u1)) * sin(2 * pi * u2);
            print mu + sigma * z0;
            if (i + 1 <= count) print mu + sigma * z1;
        }
    }'
}

neumann() {
    local count=$1 mu=$2 sigma=$3 seed=$4
    awk -v count="$count" -v mu="$mu" -v sigma="$sigma" -v seed="$seed" '
    BEGIN {
        if (seed != "") srand(seed); else srand();
        generated = 0;
        while (generated < count) {
            x = 10 * rand() - 5;
            y = rand();
            if (y <= exp(-x * x / 2)) {
                print mu + sigma * x;
                generated++;
            }
        }
    }'
}

marsaglia_bray() {
    local count=$1 mu=$2 sigma=$3 seed=$4
    awk -v count="$count" -v mu="$mu" -v sigma="$sigma" -v seed="$seed" '
    BEGIN {
        if (seed != "") srand(seed); else srand();
        generated = 0;
        while (generated < count) {
            v1 = 2 * rand() - 1;
            v2 = 2 * rand() - 1;
            s = v1 * v1 + v2 * v2;
            if (s < 1 && s > 0) {
                factor = sqrt(-2 * log(s) / s);
                z1 = v1 * factor;
                z2 = v2 * factor;
                print mu + sigma * z1;
                generated++;
                if (generated < count) {
                    print mu + sigma * z2;
                    generated++;
                }
            }
        }
    }'
}

print_header() {
    clear
    echo "=================================================="
    echo "       Генератор нормальных чисел"
    echo "=================================================="
    echo "Текущие параметры:"
    echo "  количество = $COUNT"
    echo "  μ = $MU"
    echo "  σ = $SIGMA"
    [[ -n "$SEED" ]] && echo "  seed = $SEED" || echo "  seed = не задан"
    echo "  метод = ${METHOD_NAMES[$METHOD-1]}"
    echo "--------------------------------------------------"
}

show_menu() {
    echo "Выберите действие:"
    echo "1. Задать параметры"
    echo "2. Выбрать метод генерации"
    echo "3. Сгенерировать и показать числа"
    echo "4. Сохранить в файл"
    echo "5. Статистика"
    echo "6. Гистограмма"
    echo "7. О программе"
    echo "8. Выход"
    echo -n "Ваш выбор: "
}

set_parameters() {
    echo "--- Параметры генерации ---"
    prompt_number "Количество чисел (целое >0): " COUNT "yes" "no"
    prompt_number "Математическое ожидание μ: " MU "no" "yes"
    prompt_number "Стандартное отклонение σ (>0): " SIGMA "yes" "yes"
    echo -n "Seed для воспроизводимости (целое число, или оставьте пустым): "
    read seed_input
    if [[ -n "$seed_input" ]]; then
        if [[ "$seed_input" =~ ^[0-9]+$ ]]; then
            SEED="$seed_input"
        else
            echo "Ошибка: seed должен быть целым неотрицательным числом. Seed не используется."
            SEED=""
        fi
    else
        SEED=""
    fi
    echo "Параметры обновлены."
    read -p "Нажмите Enter для продолжения..."
}

choose_method() {
    echo "--- Выбор метода генерации ---"
    echo "1. Бокса-Мюллера"
    echo "2. Неймана (rejection sampling)"
    echo "3. Марсальи-Брея (полярный)"
    prompt_number "Выберите метод (1-3): " METHOD "no" "no"
    if [[ "$METHOD" -lt 1 || "$METHOD" -gt 3 ]]; then
        echo "Ошибка: выберите 1, 2 или 3. Установлен метод по умолчанию (1)."
        METHOD=1
    fi
    echo "Метод установлен: ${METHOD_NAMES[$METHOD-1]}"
    read -p "Нажмите Enter для продолжения..."
}

generate_and_print() {
    echo "--- Генерация чисел ---"
    case $METHOD in
        1) generator="box_muller" ;;
        2) generator="neumann" ;;
        3) generator="marsaglia_bray" ;;
        *) generator="box_muller" ;;
    esac
    echo "Генерация методом ${METHOD_NAMES[$METHOD-1]}..."
    NUMBERS=()
    local temp_file=$(mktemp)
    $generator "$COUNT" "$MU" "$SIGMA" "$SEED" > "$temp_file"
    while IFS= read -r num; do
        NUMBERS+=("$num")
    done < "$temp_file"
    rm -f "$temp_file"
    echo "Сгенерировано ${#NUMBERS[@]} чисел."

    if [[ ${#NUMBERS[@]} -gt 100 ]]; then
        echo "Числа не выводятся на экран (их больше 100), но сохранены в памяти."
        echo "Вы можете сохранить их в файл (пункт 4) или построить статистику/гистограмму."
    else
        echo "Список чисел:"
        for i in "${!NUMBERS[@]}"; do
            printf "%3d: %10.6f  " $((i+1)) "${NUMBERS[i]}"
            if (( (i+1) % 5 == 0 )); then echo; fi
        done
        [[ $((${#NUMBERS[@]} % 5)) != 0 ]] && echo
    fi
    read -p "Нажмите Enter для продолжения..."
}

save_to_file() {
    if [[ ${#NUMBERS[@]} -eq 0 ]]; then
        echo "Нет сгенерированных чисел. Сначала выполните пункт 3."
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    echo "--- Сохранение в файл ---"
    echo -n "Введите имя файла: "
    read filename
    if [[ -z "$filename" ]]; then
        echo "Имя файла не может быть пустым."
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    printf "%s\n" "${NUMBERS[@]}" > "$filename"
    echo "Сохранено ${#NUMBERS[@]} чисел в файл '$filename'."
    read -p "Нажмите Enter для продолжения..."
}

show_stats() {
    if [[ ${#NUMBERS[@]} -eq 0 ]]; then
        echo "Нет данных. Сначала сгенерируйте числа."
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    echo "--- Статистика ---"
    printf "%s\n" "${NUMBERS[@]}" | awk '
    BEGIN {
        min = 1e308; max = -1e308; sum = 0; sum2 = 0; n = 0;
    }
    {
        n++;
        sum += $1;
        sum2 += $1 * $1;
        if ($1 < min) min = $1;
        if ($1 > max) max = $1;
    }
    END {
        mean = sum / n;
        if (n > 1)
            var = (sum2 - sum * sum / n) / (n - 1);
        else
            var = 0;
        printf "Количество: %d\n", n;
        printf "Среднее:    %.10f\n", mean;
        printf "Дисперсия:  %.10f\n", var;
        printf "Минимум:    %.10f\n", min;
        printf "Максимум:   %.10f\n", max;
    }'
    read -p "Нажмите Enter для продолжения..."
}

show_histogram() {
    if [[ ${#NUMBERS[@]} -eq 0 ]]; then
        echo "Нет данных. Сначала сгенерируйте числа."
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    echo "--- Гистограмма (10 интервалов) ---"
    printf "%s\n" "${NUMBERS[@]}" | awk '
    BEGIN {
        bins = 10;
        width = 0;
        min = 1e308; max = -1e308;
    }
    {
        if ($1 < min) min = $1;
        if ($1 > max) max = $1;
        data[NR] = $1;
    }
    END {
        n = NR;
        if (n == 0) exit;
        if (min == max) {
            printf "Все числа равны %.6f\n", min;
            exit;
        }
        width = (max - min) / bins;
        for (i = 1; i <= bins; i++) freq[i] = 0;
        for (i = 1; i <= n; i++) {
            idx = int((data[i] - min) / width) + 1;
            if (idx > bins) idx = bins;
            freq[idx]++;
        }
        for (i = 1; i <= bins; i++) {
            left = min + (i-1)*width;
            right = (i == bins) ? max : min + i*width;
            stars = int(50 * freq[i] / n);
            printf "[%8.3f - %8.3f] |", left, right;
            for (j = 1; j <= stars; j++) printf "*";
            printf " (%d)\n", freq[i];
        }
    }'
    read -p "Нажмите Enter для продолжения..."
}

about() {
    echo "--- О программе ---"
    echo "Генератор нормально распределенных случайных чисел"
    echo ""
    echo "Программа позволяет генерировать последовательности чисел,"
    echo "подчиняющихся нормальному закону распределения, с заданными"
    echo "параметрами (математическое ожидание и стандартное отклонение)."
    echo ""
    echo "Реализованные методы:"
    echo "  1. Бокса–Мюллера  — преобразование двух равномерных величин"
    echo "  2. Неймана (rejection sampling) — метод исключения"
    echo "  3. Марсальи–Брея (полярный метод) — вариант Бокса–Мюллера"
    echo ""
    echo "Функциональные возможности:"
    echo "  • Задание параметров генерации (количество, μ, σ, seed)"
    echo "  • Вывод чисел на экран (при количестве >100 числа не выводятся)"
    echo "  • Сохранение результатов в файл"
    echo "  • Расчёт статистических характеристик (среднее, дисперсия, минимум, максимум)"
    echo "  • Построение текстовой гистограммы распределения"
    echo ""
    echo "Авторы:"
    echo "  Щудро И.А., Хабиров А.А., Руднев Н.А."
    read -p "Нажмите Enter для продолжения..."
}

while true; do
    print_header
    show_menu
    read choice
    case $choice in
        1) set_parameters ;;
        2) choose_method ;;
        3) generate_and_print ;;
        4) save_to_file ;;
        5) show_stats ;;
        6) show_histogram ;;
        7) about ;;
        8) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор, попробуйте снова."; read -p "Нажмите Enter..." ;;
    esac
done
