# PHP-Httpd-Socket — учебный стек на Docker (современная замена XAMPP/MAMP/Open Server)

Простая, воспроизводимая и «говорящая» среда для изучения PHP и его экосистемы. Стек собирается из контейнеров Docker и предназначен для локальной разработки и экспериментов.

Важно: этот проект предназначен исключительно для обучения, практики и ознакомления. Не используйте его в production.

## Архитектура

Сервисы docker-compose.yml:
- PHP-FPM 8.4 (контейнер php-httpd-socket) — выполняет PHP, слушает Unix-socket; Xdebug установлен и управляется переменными окружения.
- Apache HTTP Server 2.4 (контейнер httpd-socket) — отдаёт статику и проксирует .php в PHP-FPM через Unix-socket; доступен на http://localhost:80.
- MySQL 8.4 (контейнер mysql-httpd-socket) — база данных на localhost:3306; данные в именованном томе mysql-data.
- phpMyAdmin (контейнер phpmyadmin) — веб-интерфейс MySQL на http://localhost:8080.

Healthchecks:
- PHP-FPM — cgi-fcgi -bind -connect /var/run/php/php-fpm.sock
- Apache — HTTP-запрос к http://localhost
- MySQL — mysqladmin ping
- phpMyAdmin — HTTP-запрос к http://localhost

Порядок старта: httpd-socket ожидает, когда php-httpd-socket станет healthy.

## Структура репозитория

```
php-httpd-socket/
├── Makefile
├── README.md
├── config/
│   ├── httpd/
│   │   └── httpd.conf          # Конфиг Apache (mod_proxy_fcgi → PHP-FPM по Unix-socket)
│   └── php/
│       ├── php.ini             # Dev-настройки PHP + Xdebug через env
│       └── www.conf            # Пул FPM: listen=/var/run/php/php-fpm.sock и права на сокет
├── docker/
│   └── php.Dockerfile          # Образ PHP-FPM 8.4 (Alpine) + расширения + Xdebug + Composer
├── docker-compose.yml          # Основной стек: PHP-FPM (socket), Apache, MySQL, phpMyAdmin
├── docker-compose.xdebug.yml   # Оверлей: включает Xdebug через переменные окружения
├── env/
│   └── .env.example            # Шаблон переменных окружения (скопируйте в env/.env)
└── public/                     # DocumentRoot (общий для Apache и PHP-FPM)
    └── index.php
```

Примечание: для учебных целей достаточно размещать PHP-файлы в public/.

## Быстрый старт

Предпосылки:
- Docker 20.10+
- Docker Compose v2+

Шаги:
1) Клонируйте репозиторий и перейдите в каталог проекта.
2) Создайте файл с переменными окружения:
   - mkdir -p env && cp env/.env.example env/.env
   - при необходимости отредактируйте значения (пароли БД и пр.).
3) Запустите стек:
   - make up
4) Проверьте доступность:
   - Web:        http://localhost
   - phpMyAdmin: http://localhost:8080 (сервер: mysql-httpd-socket)
   - MySQL:      localhost:3306

Полезные команды Makefile:
- make setup — создать env/.env из примера
- make up / make down / make restart — управление стеком
- make logs / make status — логи и статусы контейнеров
- make xdebug-up / make xdebug-down — запуск/остановка стека с включённым Xdebug

## Конфигурация

PHP (config/php/php.ini):
- error_reporting=E_ALL, display_errors=On — удобно учиться на ошибках
- memory_limit=256M, upload_max_filesize=20M, post_max_size=20M
- OPCache включён, validate_timestamps=1 (горячая перезагрузка кода)
- Xdebug управляется через переменные окружения (см. раздел «Xdebug»)

PHP-FPM (config/php/www.conf):
- listen = /var/run/php/php-fpm.sock
- listen.owner = www-data, listen.group = daemon, listen.mode = 0660

Apache (config/httpd/httpd.conf):
- Включён mod_proxy_fcgi
- Проксирование .php в PHP-FPM через Unix-socket:
  ProxyPassMatch ^/(.*\.php(/.*)?)$ unix:/var/run/php/php-fpm.sock|fcgi://localhost/var/www/html/$1
- AllowOverride All для /var/www/html — можно использовать .htaccess (например, mod_rewrite)

Docker-образ PHP (docker/php.Dockerfile):
- База: php:8.4-fpm-alpine
- Установлены расширения: pdo, pdo_mysql, mysqli, mbstring, xml, gd, bcmath, zip
- Установлены: Xdebug (pecl), Composer, fcgi (для healthcheck)
- Порт 9000 наружу не пробрасывается, связь Apache↔FPM — только через Unix-socket

Общий том для сокета:
- Оба контейнера (PHP-FPM и Apache) монтируют общий путь /var/run/php (именованный том unix-socket)
- Путь сокета: /var/run/php/php-fpm.sock

## Переменные окружения (env/.env)

Минимальный набор (см. env/.env.example):
- MYSQL_ROOT_PASSWORD — пароль root для MySQL
- MYSQL_DATABASE — имя создаваемой БД
- MYSQL_USER, MYSQL_PASSWORD — пользователь и пароль
- PMA_HOST=mysql-httpd-socket, PMA_ARBITRARY=1 — для phpMyAdmin
- Переменные Xdebug (см. ниже)

## Xdebug: как включить

По умолчанию Xdebug установлен, но выключен. Включить можно двумя способами.

Вариант A — оверлейный compose-файл:
- make xdebug-up
  (эквивалент docker-compose -f docker-compose.yml -f docker-compose.xdebug.yml up -d)
- Внутри php.ini используются переменные XDEBUG_MODE=debug и XDEBUG_START=yes

Вариант B — через env/.env и перезапуск контейнера PHP:
- XDEBUG_MODE=debug
- XDEBUG_START=yes
- затем docker-compose up -d --no-deps php-httpd-socket

IDE: подключение Xdebug 3 на порт 9003, client_host=host.docker.internal.

## Монтирования и данные

- public/ монтируется в /var/www/html в PHP-FPM и Apache — изменения видны сразу
- config/php/php.ini → /usr/local/etc/php/conf.d/local.ini (ro)
- config/php/www.conf → /usr/local/etc/php-fpm.d/www.conf (ro)
- Именованные тома: mysql-data (данные БД), unix-socket (сокет FPM)

## Подключение к MySQL из PHP (пример)

```php
<?php
$host = 'mysql-httpd-socket';
$dbname = 'your-db-name';
$user = 'your-user';
$pass = 'your-user-password';
$pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $user, $pass);
```

## Решение проблем

Права на Unix-socket:
- Если Apache не может связаться с PHP-FPM, проверьте права на /var/run/php/php-fpm.sock
- Убедитесь, что пользователь/группа Apache (daemon:daemon в httpd:alpine) имеет доступ по группе
- При необходимости временно задайте listen.mode=0666 (только для локальной отладки)

Совпадение путей:
- Путь к сокету в Apache должен совпадать с путём, по которому слушает PHP-FPM, и указывать на общий том

Порты заняты:
- Измените привязку портов в docker-compose.yml (например, 8080:80 для Apache, 3307:3306 для MySQL)

Порядок запуска:
- Проверьте healthchecks командой docker-compose ps; httpd-socket зависит от healthy php-httpd-socket

Xdebug не подключается:
- Убедитесь, что IDE слушает порт 9003 и заданы XDEBUG_MODE/XDEBUG_START

Полная очистка и пересборка:
- make clean или make clean-all; затем make rebuild и make up

## Дисклеймер

Проект создан для обучения и экспериментов с PHP-стеком и не предназначен для production.