# Matrix Setup & Repair Tool v5.3

Автоматизированный скрипт для установки и исправления Matrix Synapse + Element Web + Synapse Admin + PostgreSQL + Coturn на Ubuntu 20/22/24 LTS.

**🆕 НОВОЕ в v5.3: Полная совместимость с Ubuntu 24.04 LTS**

## ⚡ Быстрая установка
### **ДЛЯ НАСТРОЙКИ ПОТРЕБУЕТСЯ ТРИ ПРЕДВАРИТЕЛЬНО ПРИКРЕПЛЕННЫХ К АДРЕСУ VPS ДОМЕНА!!!**
- для Matrix Synapse
- для Element Web
- для Synapse Admin 

```bash
wget -qO setup-matrix.sh https://raw.githubusercontent.com/gopnikgame/matrix-setup/main/setup-matrix.sh && chmod +x setup-matrix.sh && sudo ./setup-matrix.sh
```

## 🔧 Исправления для Ubuntu 24.04 LTS

### Автоматическое решение проблем:
- ✅ **Системное время** - автоматическая синхронизация NTP
- ✅ **Репозитории** - переход с element.io на matrix.org
- ✅ **Пакеты** - альтернативная установка через pip
- ✅ **Сервисы** - автоматическое создание systemd конфигураций

### Быстрое исправление времени:
```bash
sudo ./setup-matrix.sh -t
```

### Полная установка с исправлениями:
```bash
sudo ./setup-matrix.sh -f
```

## 💳 Если есть желание поддержать развитие скрипта:

### 💎 Криптовалюта | Cryptocurrency
**TON Space**: `UQBh0Cgy5um8oChpXBl8O0NbTwyj1tVXH6RO07c9b3rCD4kf`
### 💳 Фиатные платежи | Fiat Payments
**CloudTips**: [https://pay.cloudtips.ru/p/244b03de](https://pay.cloudtips.ru/p/244b03de)

Ваша поддержка поможет нам продолжать совершенствовать скрипт, добавлять новые функции. Спасибо за вашу помощь! ❤️

## 🎯 Режимы работы

### 1. **Полная установка**
- Автоматическое определение типа сервера
- Правильная настройка всех binding адресов
- Установка всех компонентов с правильной конфигурацией
- **НОВОЕ**: Автоматическое исправление времени и репозиториев

### 2. **Исправление для Proxmox VPS**
- Проверяет binding адреса всех сервисов
- Исправляет на `0.0.0.0` если найден `127.0.0.1`
- Перезапускает только измененные сервисы

### 3. **Исправление для Hosting VPS**
- Проверяет binding адреса всех сервисов  
- Исправляет на `127.0.0.1` если найден `0.0.0.0`
- Перезапускает только измененные сервисы

### 4. **Проверка настроек**
- Показывает текущие binding адреса
- Определяет тип сервера
- Выводит статус всех сервисов

### 5. **НОВОЕ: Исправление системного времени**
- Устанавливает и настраивает NTP
- Синхронизирует время
- Исправляет ошибки Release файлов

## 🔧 Что исправляется

### Matrix Synapse
- `bind_addresses: ['127.0.0.1']` ➜ `bind_addresses: ['0.0.0.0']` (для Proxmox)
- `bind_addresses: ['0.0.0.0']` ➜ `bind_addresses: ['127.0.0.1']` (для хостинга)

### Coturn  
- `listening-ip=127.0.0.1` ➜ `listening-ip=LOCAL_IP` (для Proxmox)
- `listening-ip=LOCAL_IP` ➜ `listening-ip=127.0.0.1` (для хостинга)

### Docker контейнеры
- Element Web: `127.0.0.1:8080:80` ↔ `0.0.0.0:8080:80`
- Synapse Admin: `127.0.0.1:8081:80` ↔ `0.0.0.0:8081:80`

### **НОВОЕ**: Репозитории и время
- Автоматический переход с element.io на matrix.org
- Fallback на jammy для Ubuntu 24.04
- Синхронизация системного времени

## 🚀 Использование

1. Запустите скрипт:
```bash
chmod +x setup-matrix.sh
sudo ./setup-matrix.sh
```

2. Выберите нужную опцию из меню:
```
========================================
    Matrix Setup & Repair Tool v5.3
========================================
1.  Полная установка Matrix системы
2.  Исправить binding для Proxmox VPS
3.  Исправить binding для Hosting VPS
4.  Проверить текущие настройки
5.  Миграция на Element Synapse
6.  Резервное копирование конфигурации
7.  Восстановление конфигурации
8.  Обновление системы и пакетов
9.  Перезапуск всех сервисов
10. Управление федерацией
11. Управление регистрацией пользователей
12. Создать пользователя (админ)
13. Создать токен регистрации
14. Проверка версии и системы
15. Исправление системного времени ← НОВОЕ
16. Выход
========================================
```

### Аргументы командной строки:
```bash
sudo ./setup-matrix.sh -f              # Полная установка
sudo ./setup-matrix.sh -t              # Исправить время
sudo ./setup-matrix.sh -c              # Проверить статус
sudo ./setup-matrix.sh -r              # Исправить binding
sudo ./setup-matrix.sh -h              # Справка
```

## 🔐 Безопасность (Enhanced v5.3)

### Element Web
- **Content Security Policy** для предотвращения XSS
- **Permissions Policy** для ограничения API браузера
- **Кэширование** оптимизировано для производительности
- **Separate domains** рекомендуется для безопасности

### Matrix Synapse
- **HSTS Preload** для принудительного HTTPS
- **X-Frame-Options: DENY** для предотвращения clickjacking
- **Well-known endpoints** с кэшированием
- **Федерация отключена** по умолчанию

### Общие меры
- **Proxmox VPS**: Сервисы доступны с хоста, но защищены сетевой изоляцией
- **Hosting VPS**: Сервисы доступны только локально через reverse proxy
- PostgreSQL всегда ограничен localhost
- Автоматические SSL сертификаты через Caddy (только для хостинга)

## 🎮 Element Call & VoIP

### Новые возможности
- **Element Call** готов к активации в labs настройках
- **Jitsi интеграция** с собственным сервером
- **TURN сервер** оптимизирован для медиа
- **Well-known** содержит настройки VoIP

### Активация Element Call
1. Войдите в Element Web
2. Настройки → Labs
3. Включите "New group call experience"
4. Перезапустите Element Web

## 📊 Мониторинг

Скрипт автоматически проверяет:
- Текущие binding адреса всех сервисов
- Статус запущенных Docker контейнеров  
- Корректность настроек для типа сервера
- Необходимость перезапуска сервисов
- **НОВОЕ**: Синхронизацию системного времени

## 🔄 Changelog

### Версия 5.3 (Ubuntu 24.04 LTS Compatible)
- **ИСПРАВЛЕНО**: Полная совместимость с Ubuntu 24.04 LTS (Noble Numbat)
- **ДОБАВЛЕНО**: Автоматическое исправление системного времени
- **ИСПРАВЛЕНО**: Переход с element.io на matrix.org репозиторий
- **ДОБАВЛЕНО**: Альтернативная установка Synapse через pip
- **УЛУЧШЕНО**: Управление репозиториями с fallback на jammy
- **ДОБАВЛЕНО**: Повторные попытки обновления репозиториев
- **ИСПРАВЛЕНО**: Создание пользователя matrix-synapse если отсутствует
- **ДОБАВЛЕНО**: Командные аргументы для быстрого доступа

### Версия 5.2 (Enhanced Security & Element Call)
- **ДОБАВЛЕНО**: Element Call поддержка
- **ДОБАВЛЕНО**: Расширенная конфигурация Element Web (50+ опций)
- **ДОБАВЛЕНО**: Well-known endpoints с E2EE и Jitsi настройками
- **УЛУЧШЕНО**: Content Security Policy для Element Web
- **УЛУЧШЕНО**: Permissions Policy для ограничения API
- **ДОБАВЛЕНО**: Оптимизированное кэширование статических ресурсов
- **ДОБАВЛЕНО**: Проверка доменов на XSS безопасность
- **УЛУЧШЕНО**: Заголовки безопасности (HSTS Preload, X-Robots-Tag)

## 🛠️ Устранение проблем Ubuntu 24.04

### Проблемы с временем:
```bash
# Симптомы:
E: Файл Release для http://ru.archive.ubuntu.com/ubuntu/dists/noble-updates/InRelease пока не действителен

# Решение:
sudo ./setup-matrix.sh -t
```

### Проблемы с репозиториями:
```bash
# Симптомы:
E: Репозиторий «https://packages.element.io/debian noble Release» не содержит файла Release.
E: Невозможно найти пакет matrix-synapse-py3

# Решение: скрипт автоматически переключается на matrix.org
```

### Проблемы с установкой:
```bash
# Симптомы:
./setup-matrix.sh: line 598: /etc/matrix-synapse/homeserver.yaml: No such file or directory
chown: invalid user: 'matrix-synapse:matrix-synapse'

# Решение: скрипт автоматически использует pip установку
```

Подробное руководство: [UBUNTU_24_04_TROUBLESHOOTING.md](UBUNTU_24_04_TROUBLESHOOTING.md)

## 🎯 Совместимость

- ✅ **Ubuntu 24.04 LTS (Noble Numbat)** - ПОЛНАЯ ПОДДЕРЖКА
- ✅ Ubuntu 22.04 LTS (Jammy Jellyfish)  
- ✅ Ubuntu 20.04 LTS (Focal Fossa)
- ✅ Proxmox VPS (с правильным binding `0.0.0.0`)
- ✅ Обычный хостинг VPS (с безопасным binding `127.0.0.1`)
- ✅ Исправление существующих установок
- ✅ Element Call & enhanced VoIP support
- ✅ Modern security standards compliance

## 🔗 Полезные ссылки

- [Element Web Documentation](https://github.com/element-hq/element-web)
- [Matrix Synapse Documentation](https://matrix-org.github.io/synapse/latest/)
- [Element Call Documentation](https://github.com/element-hq/element-call)
- [Proxmox VPS Template](proxmox-caddyfile-template.txt)
- [Synapse Admin Guide](synapse-admin-guide.md)
- [Ubuntu 24.04 Troubleshooting](UBUNTU_24_04_TROUBLESHOOTING.md)

