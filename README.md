# PHP-Apache-Socket — учебный стек на Docker (современная замена XAMPP/MAMP/Open Server)

Простая, воспроизводимая и «говорящая» среда для изучения PHP и его экосистемы. Стек собирается из контейнеров Docker и предназначен для локальных экспериментов.

Важное: этот проект предназначен исключительно для обучения, практики и ознакомления. Не используйте его в проде.

## Что внутри (архитектура)

Сервисы docker-compose.yml:
- PHP-FPM 8.4 (контейнер php-apache-socket) — выполняет PHP, слушает Unix-socket, Xdebug установлен, управляется переменными окружения.
- Apache HTTP Server 2.4 (контейнер apache-socket) — отдаёт статику и проксирует .php в PHP-FPM через Unix-socket; доступен на http://localhost:80.
- MySQL 8.4 (контейнер mysql-apache-socket) — база данных на localhost:3306, данные в именованном томе mysql-data.
- phpMyAdmin (контейнер phpmyadmin) — веб-интерфейс MySQL на http://localhost:8080.

Здоровье (healthchecks):
- PHP-FPM — проверка fastcgi через сокет (cgi-fcgi -connect /var/run/php/php-fpm.sock).
- Apache — HTTP-запрос к http://localhost/.
- MySQL — mysqladmin ping.
- phpMyAdmin — HTTP-запрос к http://localhost/.

Порядок старта: apache-socket ожидает, когда php-apache-socket станет healthy.

## Структура репозитория (актуальная)

```
php-apache-socket/
├── Makefile
├── README.md
├── config/
│   ├── apache/
│   │   └── httpd.conf          # Конфиг Apache (проксирование в PHP-FPM по Unix-socket)
│   └── php/
│       └── php.ini             # Конфиг PHP (dev-настройки + Xdebug через env)
├── docker/
│   └── php.Dockerfile          # Образ PHP-FPM 8.4 (Alpine) + расширения + Xdebug + Composer
├── docker-compose.yml          # Основной стек: PHP-FPM (socket), Apache (proxy_fcgi), MySQL, phpMyAdmin
├── docker-compose.xdebug.yml   # Оверлей для включения Xdebug (mode=start)
├── docs/
│   ├── AI-CONTEXT.md           # Контекст/гайдлайны для AI
│   └── enhancement-plan.md     # Идеи по улучшению
├── env/
│   └── .env.example            # Пример переменных окружения (скопируйте в env/.env)
└── public/                     # DocumentRoot (монтируется в Apache и PHP-FPM)
    ├── index.html
    ├── index.php
    └── phpinfo.php
```


Обратите внимание: папки src/ и logs/ отсутствуют. Для обучения достаточно размещать PHP-файлы в public/.

## Быстрый старт

Предпосылки:
- Docker 20.10+
- Docker Compose v2+

Шаги:
1) Клонируйте репозиторий и перейдите в каталог проекта.
2) Скопируйте пример env:
    - mkdir -p env && cp env/.env.example env/.env
    - при необходимости отредактируйте пароли/имена БД.
3) Запустите стек:
    - make up (или docker compose up -d)
4) Проверьте доступность:
    - Web: http://localhost
    - phpMyAdmin: http://localhost:8080 (сервер mysql-apache-socket)
    - MySQL: localhost:3306

Полезные команды Makefile:
- make setup — создать env/.env из примера
- make up / make down / make restart — управление стеком
- make logs / make status — логи и статусы контейнеров
- make xdebug-up / make xdebug-down — запуск/остановка стека с включённым Xdebug

## Конфигурация

PHP (config/php/php.ini):
- error_reporting=E_ALL, display_errors=On — удобно учиться на ошибках
- memory_limit=256M, upload_max_filesize=20M, post_max_size=20M
- opcache включён, validate_timestamps=1 (код обновляется сразу)
- Xdebug управляется через переменные окружения (см. ниже)

Apache (config/apache/httpd.conf):
- Включён mod_proxy_fcgi.
- Проксирование .php в PHP-FPM через Unix-socket (например, /var/run/php/php-fpm.sock).
- AllowOverride All в /var/www/html — можно использовать .htaccess (например, mod_rewrite).

Docker-образ PHP (docker/php.Dockerfile):
- База: php:8.4-fpm-alpine.
- Установлены расширения: pdo, pdo_mysql, mysqli, mbstring, xml, gd, bcmath, zip.
- Установлен Xdebug (через pecl), Composer, fcgi (для healthcheck).
- PHP-FPM слушает Unix-socket; порт 9000 наружу не используется.

Общий каталог для сокета:
- Оба контейнера (PHP-FPM и Apache) монтируют общий путь для сокета, например /var/run/php.
- Путь сокета по умолчанию: /var/run/php/php-fpm.sock.

Права на сокет:
- Рекомендуется настроить listen.owner / listen.group и listen.mode=660 так, чтобы Apache имел доступ.
- Для упрощения в учебных целях можно использовать listen.mode=666 (пониженная безопасность — только в локальной среде).

## Переменные окружения (env/.env)

Минимальный набор (см. env/.env.example):
- MYSQL_ROOT_PASSWORD — пароль root для MySQL
- MYSQL_DATABASE — имя создаваемой БД
- MYSQL_USER, MYSQL_PASSWORD — пользователь и его пароль
- PMA_HOST=mysql-apache-socket, PMA_ARBITRARY=1 — для phpMyAdmin
- Переменные Xdebug (см. ниже)

## Xdebug: как включить

По умолчанию Xdebug установлен, но выключен (переменные не заданы). Включить можно двумя способами:

Вариант A: оверлейный compose-файл
- make xdebug-up
  (эквивалент docker compose -f docker-compose.yml -f docker-compose.xdebug.yml up -d)
- Внутри php.ini используются переменные XDEBUG_MODE=debug и XDEBUG_START=yes.

Вариант B: задать переменные в env/.env и перезапустить php-контейнер
- XDEBUG_MODE=debug
- XDEBUG_START=yes
- затем docker compose up -d --no-deps php-apache-socket

IDE: подключение по Xdebug 3 на порт 9003, client_host=host.docker.internal.

## Рабочие директории и монтирование

- public/ монтируется в /var/www/html одновременно в PHP-FPM и Apache — любые изменения видны сразу.
- config/php/php.ini монтируется в /usr/local/etc/php/conf.d/local.ini (только чтение).
- Для MySQL используется именованный том mysql-data (персистентные данные).
- Для Unix-socket используется общий том/каталог (например, /var/run/php), смонтированный в PHP-FPM и Apache.

## Подключение к MySQL из PHP (пример)

```php
<?php
$host = 'mysql-apache-socket';
$dbname = 'your-db-name';
$user = 'your-user';
$pass = 'your-user-password';
$pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $user, $pass);
```


## Решение проблем

Права на Unix-socket:
- Если Apache не может связаться с PHP-FPM, проверьте права на /var/run/php/php-fpm.sock.
- Убедитесь, что пользователь/группа Apache имеет доступ (или временно задайте listen.mode=666).

Несовпадение путей:
- Путь к сокету в Apache должен совпадать с путём, по которому слушает PHP-FPM (и указывать на общий том/каталог, смонтированный в оба контейнера).

Порты заняты:
- Измените привязку в docker-compose.yml, например 8080:80 для Apache, 3307:3306 для MySQL.

Контейнеры не стартуют по порядку:
- Проверьте healthchecks командой docker compose ps; apache-socket зависит от healthy php-apache-socket.

Xdebug не подключается:
- Проверьте, что используете порт 9003 в IDE, и что XDEBUG_MODE/START заданы (compose.xdebug.yml или env/.env).

Полная очистка и пересборка:
- make clean или make clean-all; затем make rebuild и make up.

## Дисклеймер

Проект создан для обучения и экспериментов с PHP-стеком. Не предназначен для production-использования или оценки производительности.

—  
Если нужна шпаргалка по архитектуре и договорённостям для AI, см. docs/AI-CONTEXT.md.