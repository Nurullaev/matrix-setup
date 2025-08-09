# Matrix Setup & Repair Tool v5.4

Автоматизированный скрипт для установки и исправления Matrix Synapse + Element Web + Synapse Admin + PostgreSQL + Coturn на Ubuntu 20/22/24 LTS.

**🆕 НОВОЕ в v5.4: Docker установка Synapse + исправление systemd-python на Ubuntu 24.04**

## ⚡ Быстрая установка
### **ДЛЯ НАСТРОЙКИ ПОТРЕБУЕТСЯ ТРИ ПРЕДВАРИТЕЛЬНО ПРИКРЕПЛЕННЫХ К АДРЕСУ VPS ДОМЕНА!!!**
- для Matrix Synapse
- для Element Web
- для Synapse Admin 

```bash
wget -qO setup-matrix.sh https://raw.githubusercontent.com/gopnikgame/matrix-setup/main/setup-matrix.sh && chmod +x setup-matrix.sh && sudo ./setup-matrix.sh
```

## 🐳 Новое: Docker установка Synapse

### Автоматический выбор метода установки:
1. **🐳 Docker** (рекомендуется) - стабильно, изолированно, без проблем зависимостей
2. **📦 Package** - из репозитория matrix.org 
3. **🐍 Pip** - альтернативная установка с исправлением systemd-python

### Преимущества Docker установки:
- ✅ Решает проблемы с systemd-python на Ubuntu 24.04
- ✅ Изолированная среда выполнения
- ✅ Легкие обновления
- ✅ Встроенный PostgreSQL контейнер
- ✅ Healthcheck мониторинг

## 🔧 Исправления для Ubuntu 24.04 LTS

### Автоматическое решение проблем:
- ✅ **Системное время** - автоматическая синхронизация NTP
- ✅ **Репозитории** - переход с element.io на matrix.org
- ✅ **systemd-python** - установка без systemd модуля если он недоступен
- ✅ **pkg-config** - автоматическая установка необходимых зависимостей
- ✅ **Сервисы** - автоматическое создание systemd конфигураций
- ✅ **Signing key** - автоматическая генерация через Synapse в правильном формате
- ✅ **Coturn оптимизация** - быстрый запуск с сокращенным диапазоном портов

### Быстрые команды:
```bash
# Исправление времени
sudo ./setup-matrix.sh -t

# Полная установка с Docker
sudo ./setup-matrix.sh -f

# Проверка статуса
sudo ./setup-matrix.sh -c

# Управление Coturn отдельно (новое в v6.0)
sudo ./setup-matrix.sh
# Выберите опцию "11. 📞 Управление Coturn"
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
- **НОВОЕ**: Автоматический выбор метода установки (Docker/Package/Pip)
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

### 5. **НОВОЕ: Docker управление**
- Установка через Docker Compose
- Встроенный PostgreSQL
- Легкое обновление и управление

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

### **НОВОЕ**: Проблемы Ubuntu 24.04
- systemd-python ошибки установки
- pkg-config зависимости
- Синхронизация системного времени
- Fallback репозитории

## 🚀 Использование

1. Запустите скрипт:
```bash
chmod +x setup-matrix.sh
sudo ./setup-matrix.sh
```

2. Выберите нужную опцию из меню:
```
========================================
    Matrix Setup & Repair Tool v5.4
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

## 🐳 Docker управление

### Основные команды:
```bash
# Статус контейнеров
docker-compose -f /opt/synapse-config/docker-compose.yml ps

# Логи Synapse
docker logs matrix-synapse

# Создание администратора
docker exec -it matrix-synapse register_new_matrix_user \
  -c /data/homeserver.yaml -u admin --admin http://localhost:8008

# Обновление Synapse
cd /opt/synapse-config && docker-compose pull && docker-compose up -d
```

Подробнее: [Docker Installation Guide](DOCKER_INSTALLATION_GUIDE.md)

## 🔐 Безопасность (Enhanced v5.4)

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
- PostgreSQL всегда ограничен localhost или Docker сетью
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
4. Перезагрузите Element Web

## 📊 Мониторинг

Скрипт автоматически проверяет:
- Текущие binding адреса всех сервисов
- Статус запущенных Docker контейнеров  
- Корректность настроек для типа сервера
- Необходимость перезапуска сервисов
- **НОВОЕ**: Синхронизацию системного времени
- **НОВОЕ**: Healthcheck контейнеров

## 🔄 Changelog

### Версия 5.4 (Docker & systemd-python fixes)
- **ДОБАВЛЕНО**: Docker установка Synapse (рекомендуется)
- **ИСПРАВЛЕНО**: Проблемы с systemd-python на Ubuntu 24.04
- **ДОБАВЛЕНО**: Автоматический выбор метода установки
- **УЛУЧШЕНО**: Установка зависимостей (pkg-config, libsystemd-dev)
- **ДОБАВЛЕНО**: Fallback установка без systemd модуля
- **УЛУЧШЕНО**: Обработка ошибок установки
- **ДОБАВЛЕНО**: Docker Compose с PostgreSQL контейнером
- **ДОБАВЛЕНО**: Healthcheck мониторинг для Docker

### Версия 5.3 (Ubuntu 24.04 LTS Compatible)
- **ИСПРАВЛЕНО**: Полная совместимость с Ubuntu 24.04 LTS (Noble Numbat)
- **ДОБАВЛЕНО**: Автоматическое исправление системного времени
- **ИСПРАВЛЕНО**: Переход с element.io на matrix.org репозиторий
- **ДОБАВЛЕНО**: Альтернативная установка Synapse через pip
- **УЛУЧШЕНО**: Управление репозиториями с fallback на jammy
- **ДОБАВЛЕНО**: Повторные попытки обновления репозиториев
- **ИСПРАВЛЕНО**: Создание пользователя matrix-synapse если отсутствует
- **ДОБАВЛЕНО**: Командные аргументы для быстрого доступа

## 🛠️ Устранение проблем Ubuntu 24.04

### Проблемы с systemd-python:
```bash
# Симптомы:
FileNotFoundError: [Errno 2] No such file or directory: 'pkg-config'
error: metadata-generation-failed

# Решение: скрипт автоматически использует Docker или pip без systemd
```

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

# Решение: скрипт автоматически переключается на matrix.org
```

Подробное руководство: [Ubuntu 24.04 Troubleshooting](UBUNTU_24_04_TROUBLESHOOTING.md)

## 🎯 Совместимость

- ✅ **Ubuntu 24.04 LTS (Noble Numbat)** - ПОЛНАЯ ПОДДЕРЖКА + Docker
- ✅ Ubuntu 22.04 LTS (Jammy Jellyfish)  
- ✅ Ubuntu 20.04 LTS (Focal Fossa)
- ✅ Proxmox VPS (с правильным binding `0.0.0.0`)
- ✅ Обычный хостинг VPS (с безопасным binding `127.0.0.1`)
- ✅ Исправление существующих установок
- ✅ Element Call & enhanced VoIP support
- ✅ Modern security standards compliance
- ✅ **Docker установка** - решает все проблемы зависимостей

## 🔗 Полезные ссылки

- [Element Web Documentation](https://github.com/element-hq/element-web)
- [Matrix Synapse Documentation](https://matrix-org.github.io/synapse/latest/)
- [Element Call Documentation](https://github.com/element-hq/element-call)
- [Docker Installation Guide](DOCKER_INSTALLATION_GUIDE.md)
- [Proxmox VPS Template](proxmox-caddyfile-template.txt)
- [Synapse Admin Guide](synapse-admin-guide.md)
- [Ubuntu 24.04 Troubleshooting](UBUNTU_24_04_TROUBLESHOOTING.md)
- [Signing Key Troubleshooting](SIGNING_KEY_TROUBLESHOOTING.md)
- [Coturn Troubleshooting](COTURN_TROUBLESHOOTING.md)

