# Отчёт: архитектура и взаимодействие базы данных 

## 1. Общая архитектура

Проект **Function Plotter** использует трёхзвенную архитектуру: 
- **Сервер** написан на C++ с использованием Qt (`QTcpServer`, `QSqlDatabase`)
- **База данных** — PostgreSQL (контейнер `function_plotter_postgres`)
- **Клиент** — Qt-приложение (client.exe из `release.rar`)

## Этапы работы с БД

### Этап 1: Регистрация
1. Проверка уникальности `login` и `email`
2. Хэширование пароля (SHA-256)
3. Вставка записи в таблицу `users`

### Этап 2: Авторизация
1. Поиск пользователя по `login`
2. Сравнение хэша введённого пароля с хэшем в БД

### Этап 3: Восстановление пароля
1. Генерация 6-значного токена
2. Сохранение токена и времени истечения (`reset_token`, `reset_token_expires`)
3. Отправка токена на email
4. Проверка токена при сбросе
5. Обновление пароля и очистка токена

### Этап 4: Просмотр данных
- Получение информации о пользователе по `login` или `email`


## 2. Структура базы данных 

# Модель базы данных

## ER-диаграмма


*users*

| id                  | PK, SERIAL                          |
| ------------------- | ----------------------------------- |
| login               | VARCHAR(50) NOT NULL UNIQUE         |
| password            | VARCHAR(255) NOT NULL               |
| email               | VARCHAR(100) NOT NULL UNIQUE        |
| reset_token         | VARCHAR(100)                        |
| reset_token_expires | TIMESTAMP                           |
| created_at          | TIMESTAMP DEFAULT CURRENT_TIMESTAMP |


## Описание полей

| Поле                    | Тип          | Обязательное | Уникальное | Описание                              |
| ----------------------- | ------------ | ------------ | ---------- | ------------------------------------- |
| **id**                  | SERIAL       | +            | + (PK)     | Уникальный идентификатор пользователя |
| **login**               | VARCHAR(50)  | +            | +          | Логин для входа                       |
| **password**            | VARCHAR(255) | +            | -          | Хэш пароля (SHA-256)                  |
| **email**               | VARCHAR(100) | +            | +          | Email пользователя                    |
| **reset_token**         | VARCHAR(100) | -            | -          | Токен для сброса пароля (6 цифр)      |
| **reset_token_expires** | TIMESTAMP    | -            | -          | Время истечения токена                |
| **created_at**          | TIMESTAMP    | -            | -          | Дата и время регистрации              |

## Тестовые данные

| id | login | password (hash) | email |
|----|-------|-----------------|-------|
| 1 | admin | 5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8 | admin@example.com |
| 2 | alice | 8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92 | alice@example.com |
| 3 | bob | 81b637d8fcd2c6da6359e6963113a1170de795e4b725b84d1e0b4cfd9ec58ce9 | bob@example.com |

## 3. SQL-запросы к базе данных

Регистрация:
INSERT INTO users (login, password, email) VALUES (:login, :password, :email);

Проверка существования:
SELECT COUNT(*) FROM users WHERE login = :login;
SELECT COUNT(*) FROM users WHERE email = :email;

Авторизация:
SELECT password FROM users WHERE login = :login;

Получение информации:
SELECT id, login, password, email, reset_token, reset_token_expires, created_at FROM users WHERE login = :login;
SELECT id, login, password, email, reset_token, reset_token_expires, created_at FROM users WHERE email = :email;

Обновление пароля:
UPDATE users SET password = :password WHERE login = :login;

Установка токена восстановления:
UPDATE users SET reset_token = :token, reset_token_expires = :expires WHERE email = :email;

Получение email по токену:
SELECT email FROM users WHERE reset_token = :token AND reset_token_expires > NOW();

Проверка валидности токена:
SELECT COUNT(*) FROM users WHERE reset_token = :token AND reset_token_expires > NOW();

Очистка токена:
UPDATE users SET reset_token = NULL, reset_token_expires = NULL WHERE reset_token = :token;

## 4. Хэширование паролей

Хэш вычисляется по формуле: SHA-256(password). Результат — 64 символа в hex.

## 5. Протокол взаимодействия клиента с сервером (из postgresqlserver.cpp)

Команды (разделитель | ):

- reg|логин|пароль|email — регистрация
- auth|логин|пароль — авторизация
- forgot|email — запрос кода восстановления
- reset|код|новый_пароль — сброс пароля
- calc|a|b|c — вычисление графика (200 точек)

Пример регистрации:
Клиент → Сервер: "reg|alice|alice123|alice@example.com"
Сервер → Клиент: "REG_SUCCESS|alice"

Пример авторизации:
Клиент → Сервер: "auth|alice|alice123"
Сервер → Клиент: "AUTH_SUCCESS|alice"

Пример вычисления графика (ответ в JSON):
{"type":"CALC_RESPONSE","graphPoints":[{"x":-20,"y":400},...],"tablePoints":[{"x":-20,"y":400},...],"a":1,"b":0,"c":1}


## 6. Запуск и подключение

git clone https://github.com/Nanotrell/timp-project
cd timp-project
docker-compose up -d
...
(настройка  Docker Desktop)
...
docker exec -it function_plotter_postgres psql -U plotter_user -d function_plotter (подключение базы данных в контейнере)


## 7. Диаграмма

Диаграмма представлена в отдельном файле db_diagram.png

## 8. Источник

https://github.com/Nanotrell/timp-project (файлы: database.cpp, database.h, postgresqlserver.cpp, auth.cpp, update_database.sql)



