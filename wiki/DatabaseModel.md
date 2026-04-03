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

## SQL-запросы для работы с БД

### Создание таблицы
```sql
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    login VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    reset_token VARCHAR(100),
    reset_token_expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
Добавление пользователя
sql
INSERT INTO users (login, password, email) 
VALUES ('admin', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', 'admin@example.com');
Проверка авторизации
sql
SELECT password FROM users WHERE login = 'admin';
Установка токена сброса
sql
UPDATE users SET reset_token = '123456', reset_token_expires = NOW() + INTERVAL '15 minutes' 
WHERE email = 'admin@example.com';
Проверка токена
sql
SELECT email FROM users WHERE reset_token = '123456' AND reset_token_expires > NOW();
Обновление пароля
sql
UPDATE users SET password = 'new_hash', reset_token = NULL, reset_token_expires = NULL 
WHERE reset_token = '123456';
Контакты
Проект: Function Plotter

Репозиторий: https://github.com/Nanotrell/timp-project
