# Matrix Setup & Management Tool v3.0

Полнофункциональный инструмент для установки и управления Matrix Synapse сервером с Element Web клиентом и дополнительными компонентами.


### Компоненты системы

#### Основные компоненты:
- **Matrix Synapse** - основной сервер Matrix
- **PostgreSQL** - база данных
- **Element Web** - современный веб-клиент

#### Дополнительные компоненты:
- **Matrix Authentication Service (MAS)** - современная OAuth2/OIDC аутентификация
- **Coturn TURN Server** - для надежных VoIP звонков через NAT/firewall
- **Synapse Admin** - веб-интерфейс администрирования
- **Reverse Proxy** - поддержка Caddy
- **Registration Control** - управление регистрацией пользователей
- **Federation Control** - управление федерацией
- **UFW Firewall** - настройка файрвола

### Поддержка различных типов серверов
- **Proxmox VM** - автоматическая настройка для NAT
- **Облачный хостинг** - оптимизация для VPS

### Системные требования
- **OS**: Ubuntu 24.04+ или Debian 12+
- **RAM**: минимум 1GB (рекомендуется 2GB+)
- **Disk**: минимум 10GB свободного места
- **Network**: стабильное интернет-соединение
- **Domains**: предварительно настроенные домены/поддомены

## 📋 Быстрая установка

### Автоматическая установка
```bash
wget -qO get.sh https://raw.githubusercontent.com/gopnikgame/matrix-setup/main/get.sh && chmod +x get.sh && sudo ./get.sh
```

## 🏗️ Структура проекта

```
matrix-setup/
├── common/
│   └── common_lib.sh           # Общая библиотека функций
├── modules/
│   ├── core_install.sh         # Модуль установки Matrix Synapse
│   ├── element_web.sh          # Модуль установки Element Web
│   ├── coturn_setup.sh         # Модуль установки Coturn TURN Server
│   ├── caddy_config.sh         # Модуль настройки Caddy
│   ├── synapse_admin.sh        # Установка Synapse Admin
│   ├── federation_control.sh   # Управление федерацией
│   ├── registration_control.sh # Управление регистрацией
│   ├── registration_mas.sh     # Matrix Authentication Service (MAS)
│   ├── mas_manage.sh           # Управление настройками MAS
│   └── ufw_config.sh           # Настройка файрвола
├── docs/
│   ├── mas-deployment-guide.md # Руководство по развертыванию MAS
│   └── ...                     # Другие руководства
├── manager-matrix.sh           # Главный скрипт управления
├── get.sh                      # Скрипт быстрой установки
└── README.md                   # Документация
```

## 🔑 Matrix Authentication Service (MAS)

Современная система аутентификации на основе OAuth2/OIDC протоколов:

### 🌟 Основные возможности
- **OAuth2/OIDC аутентификация** - современные протоколы безопасности
- **Element X совместимость** - полная поддержка мобильных клиентов
- **SSO интеграция** - поддержка Google, GitHub, GitLab, Discord
- **Управление регистрацией** - гибкий контроль доступа
- **CAPTCHA защита** - защита от ботов
- **Токены регистрации** - контролируемая регистрация

### 📦 Установка MAS
```bash
# Через главный менеджер
sudo ./manager-matrix.sh
# → Дополнительные компоненты → Matrix Authentication Service (MAS)

# Напрямую через модуль
sudo ./modules/registration_mas.sh
```

### ⚙️ Управление MAS
```bash
# Через главный менеджер
sudo ./manager-matrix.sh
# → Дополнительные компоненты → Управление MAS (настройки)

# Напрямую через модуль управления
sudo ./modules/mas_manage.sh
```

### 🔧 Возможности управления MAS
- **Статус и диагностика** - мониторинг работы MAS
- **Управление регистрацией** - включение/отключение открытой регистрации
- **SSO провайдеры** - настройка Google, GitHub, GitLab, Discord
- **CAPTCHA настройки** - интеграция с reCAPTCHA
- **Заблокированные имена** - контроль недопустимых логинов
- **Токены регистрации** - ограниченная регистрация по приглашениям

### 🏠 Режимы работы MAS

#### Облачный хостинг
- Отдельный поддомен `auth.domain.com`
- Порт 8080 (стандартный)
- Прямой доступ к MAS

#### Домашний сервер/Proxmox  
- Работа через reverse proxy хоста
- Порт 8082 (избегает конфликтов)
- Интеграция с Caddy на хосте

## 📖 Документация

Подробные руководства доступны в папке `docs/`:
- `mas-deployment-guide.md` - Полное руководство по MAS
- `element-web-deployment-guide.md` - Настройка Element Web
- `element-web-fixes-summary.md` - Исправления архитектуры

## 📄 Лицензия

Проект распространяется под лицензией MIT.

---
## 💳 Поддержка проекта
Если вам нравится этот проект и вы хотите поддержать его развитие, вы можете сделать пожертвование

### 💎 Криптовалюта | Cryptocurrency
**TON Space**: `UQBh0Cgy5um8oChpXBl8O0NbTwyj1tVXH6RO07c9b3rCD4kf`

### 💳 Фиатные платежи | Fiat Payments
**CloudTips**: [https://pay.cloudtips.ru/p/244b03de](https://pay.cloudtips.ru/p/244b03de)

Ваша поддержка поможет нам продолжать совершенствовать бота, добавлять новые функции и поддерживать серверную инфраструктуру. Спасибо за вашу помощь! ❤️

