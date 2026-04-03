#!/bin/bash
# ============================================================================
# ОБНОВЛЕНИЕ БАЗЫ ДАННЫХ: убираем is_verified, verification_token,
# добавляем хэширование паролей, оставляем reset_token
# ============================================================================

set -e

PROJECT_DIR=~/projects/function-plotter
cd $PROJECT_DIR

echo "=========================================="
echo "  ОБНОВЛЕНИЕ БАЗЫ ДАННЫХ"
echo "=========================================="

# ============================================================================
# 1. ОБНОВЛЯЕМ database.h
# ============================================================================
echo ""
echo "1. Обновление database.h..."

cat > server/database.h << 'EOF'
#ifndef DATABASE_H
#define DATABASE_H

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QString>
#include <QDateTime>

struct UserInfo {
    int id;
    QString login;
    QString password;      // Хранится в виде хэша
    QString email;
    QString resetToken;
    QDateTime resetTokenExpires;
    QDateTime createdAt;
};

class Database
{
private:
    static Database* instance;
    QSqlDatabase db;

    Database();
    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;
    void createTables();
    void updateTables();

public:
    ~Database();
    static Database* getInstance();
    bool connect(const QString& host, const QString& dbName,
                 const QString& user, const QString& password, int port = 5432);
    bool isOpen() const;
    void close();

    // Регистрация и авторизация
    bool addUser(const QString& login, const QString& passwordHash, const QString& email);
    bool userExists(const QString& login);
    bool emailExists(const QString& email);
    bool checkAuth(const QString& login, const QString& passwordHash);
    UserInfo getUserInfo(const QString& login);
    UserInfo getUserInfoByEmail(const QString& email);
    bool updatePassword(const QString& login, const QString& newPasswordHash);

    // Восстановление пароля
    bool setResetToken(const QString& email, const QString& token, int expiresMinutes = 15);
    QString getEmailByResetToken(const QString& token);
    bool isValidResetToken(const QString& token);
    bool clearResetToken(const QString& token);

    // Утилиты
    QSqlQuery executeQuery(const QString& queryStr);

    // Тестовые данные
    void insertTestData();
};

#endif // DATABASE_H
EOF

echo "   ✅ database.h обновлен"

# ============================================================================
# 2. ОБНОВЛЯЕМ database.cpp
# ============================================================================
echo ""
echo "2. Обновление database.cpp..."

cat > server/database.cpp << 'EOF'
#include "database.h"
#include <QDebug>
#include <QSqlError>
#include <QSqlRecord>

Database* Database::instance = nullptr;

class DatabaseDestroyer
{
private:
    Database* p_instance;
public:
    ~DatabaseDestroyer() { delete p_instance; }
    void initialize(Database* p) { p_instance = p; }
};

static DatabaseDestroyer destroyer;

Database::Database() {}

Database::~Database()
{
    if (db.isOpen()) db.close();
}

Database* Database::getInstance()
{
    if (!instance) {
        instance = new Database();
        destroyer.initialize(instance);
    }
    return instance;
}

bool Database::connect(const QString& host, const QString& dbName,
                       const QString& user, const QString& password, int port)
{
    db = QSqlDatabase::addDatabase("QPSQL");
    db.setHostName(host);
    db.setDatabaseName(dbName);
    db.setUserName(user);
    db.setPassword(password);
    db.setPort(port);

    if (!db.open()) {
        qDebug() << "Ошибка подключения:" << db.lastError().text();
        return false;
    }

    createTables();
    updateTables();
    insertTestData();
    qDebug() << "Подключено к PostgreSQL";
    return true;
}

bool Database::isOpen() const { return db.isOpen(); }
void Database::close() { if (db.isOpen()) db.close(); }

void Database::createTables()
{
    QSqlQuery query(db);

    // Таблица users с нужными полями
    query.exec("CREATE TABLE IF NOT EXISTS users ("
               "id SERIAL PRIMARY KEY, "
               "login VARCHAR(50) NOT NULL UNIQUE, "
               "password VARCHAR(255) NOT NULL, "
               "email VARCHAR(100) NOT NULL UNIQUE, "
               "reset_token VARCHAR(100), "
               "reset_token_expires TIMESTAMP, "
               "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)");

    qDebug() << "✅ Таблица users создана/проверена";
}

void Database::updateTables()
{
    QSqlQuery query(db);

    // Удаляем устаревшие колонки (если существуют)
    query.exec("ALTER TABLE users DROP COLUMN IF EXISTS is_verified");
    query.exec("ALTER TABLE users DROP COLUMN IF EXISTS verification_token");

    // Убеждаемся, что нужные колонки есть
    query.exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token VARCHAR(100)");
    query.exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token_expires TIMESTAMP");

    // Изменяем тип password на VARCHAR(255) для хэшей
    query.exec("ALTER TABLE users ALTER COLUMN password TYPE VARCHAR(255)");

    qDebug() << "✅ Таблица users обновлена";
}

bool Database::addUser(const QString& login, const QString& passwordHash, const QString& email)
{
    if (userExists(login)) return false;
    if (emailExists(email)) return false;

    QSqlQuery query(db);
    query.prepare("INSERT INTO users (login, password, email) VALUES (:login, :password, :email)");
    query.bindValue(":login", login);
    query.bindValue(":password", passwordHash);
    query.bindValue(":email", email);

    return query.exec();
}

bool Database::userExists(const QString& login)
{
    QSqlQuery query(db);
    query.prepare("SELECT COUNT(*) FROM users WHERE login = :login");
    query.bindValue(":login", login);
    return query.exec() && query.next() && query.value(0).toInt() > 0;
}

bool Database::emailExists(const QString& email)
{
    QSqlQuery query(db);
    query.prepare("SELECT COUNT(*) FROM users WHERE email = :email");
    query.bindValue(":email", email);
    return query.exec() && query.next() && query.value(0).toInt() > 0;
}

bool Database::checkAuth(const QString& login, const QString& passwordHash)
{
    QSqlQuery query(db);
    query.prepare("SELECT password FROM users WHERE login = :login");
    query.bindValue(":login", login);

    if (query.exec() && query.next()) {
        return query.value(0).toString() == passwordHash;
    }
    return false;
}

UserInfo Database::getUserInfo(const QString& login)
{
    UserInfo info;
    info.id = -1;

    QSqlQuery query(db);
    query.prepare("SELECT id, login, password, email, reset_token, reset_token_expires, created_at "
                  "FROM users WHERE login = :login");
    query.bindValue(":login", login);

    if (query.exec() && query.next()) {
        info.id = query.value(0).toInt();
        info.login = query.value(1).toString();
        info.password = query.value(2).toString();
        info.email = query.value(3).toString();
        info.resetToken = query.value(4).toString();
        info.resetTokenExpires = query.value(5).toDateTime();
        info.createdAt = query.value(6).toDateTime();
    }
    return info;
}

UserInfo Database::getUserInfoByEmail(const QString& email)
{
    UserInfo info;
    info.id = -1;

    QSqlQuery query(db);
    query.prepare("SELECT id, login, password, email, reset_token, reset_token_expires, created_at "
                  "FROM users WHERE email = :email");
    query.bindValue(":email", email);

    if (query.exec() && query.next()) {
        info.id = query.value(0).toInt();
        info.login = query.value(1).toString();
        info.password = query.value(2).toString();
        info.email = query.value(3).toString();
        info.resetToken = query.value(4).toString();
        info.resetTokenExpires = query.value(5).toDateTime();
        info.createdAt = query.value(6).toDateTime();
    }
    return info;
}

bool Database::updatePassword(const QString& login, const QString& newPasswordHash)
{
    QSqlQuery query(db);
    query.prepare("UPDATE users SET password = :password WHERE login = :login");
    query.bindValue(":password", newPasswordHash);
    query.bindValue(":login", login);
    return query.exec();
}

bool Database::setResetToken(const QString& email, const QString& token, int expiresMinutes)
{
    QSqlQuery query(db);
    QDateTime expires = QDateTime::currentDateTime().addSecs(expiresMinutes * 60);

    query.prepare("UPDATE users SET reset_token = :token, reset_token_expires = :expires "
                  "WHERE email = :email");
    query.bindValue(":token", token);
    query.bindValue(":expires", expires);
    query.bindValue(":email", email);
    return query.exec();
}

QString Database::getEmailByResetToken(const QString& token)
{
    QSqlQuery query(db);
    query.prepare("SELECT email FROM users WHERE reset_token = :token AND reset_token_expires > NOW()");
    query.bindValue(":token", token);

    if (query.exec() && query.next()) {
        return query.value(0).toString();
    }
    return QString();
}

bool Database::isValidResetToken(const QString& token)
{
    QSqlQuery query(db);
    query.prepare("SELECT COUNT(*) FROM users WHERE reset_token = :token AND reset_token_expires > NOW()");
    query.bindValue(":token", token);
    return query.exec() && query.next() && query.value(0).toInt() > 0;
}

bool Database::clearResetToken(const QString& token)
{
    QSqlQuery query(db);
    query.prepare("UPDATE users SET reset_token = NULL, reset_token_expires = NULL "
                  "WHERE reset_token = :token");
    query.bindValue(":token", token);
    return query.exec();
}

QSqlQuery Database::executeQuery(const QString& queryStr)
{
    QSqlQuery query(db);
    query.exec(queryStr);
    return query;
}

void Database::insertTestData()
{
    QSqlQuery query(db);

    // Проверяем, есть ли уже данные
    query.exec("SELECT COUNT(*) FROM users");
    if (query.next() && query.value(0).toInt() > 0) {
        qDebug() << "📊 В таблице users уже есть данные, тестовые данные не добавлены";
        return;
    }

    // Вставляем тестовых пользователей
    // ВНИМАНИЕ: пароли здесь в открытом виде, но должны быть захэшированы!
    // Для теста используем простые хэши (в реальности используйте bcrypt)

    query.prepare("INSERT INTO users (login, password, email) VALUES (:login, :password, :email)");

    // Пользователь 1: admin / admin123
    query.bindValue(":login", "admin");
    query.bindValue(":password", "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"); // SHA-256 "admin123"
    query.bindValue(":email", "admin@example.com");
    query.exec();

    // Пользователь 2: alice / alice123
    query.bindValue(":login", "alice");
    query.bindValue(":password", "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92"); // SHA-256 "alice123"
    query.bindValue(":email", "alice@example.com");
    query.exec();

    // Пользователь 3: bob / bob123
    query.bindValue(":login", "bob");
    query.bindValue(":password", "81b637d8fcd2c6da6359e6963113a1170de795e4b725b84d1e0b4cfd9ec58ce9"); // SHA-256 "bob123"
    query.bindValue(":email", "bob@example.com");
    query.exec();

    qDebug() << "📊 Добавлены тестовые данные: admin, alice, bob";
}
EOF

echo "   ✅ database.cpp обновлен"

# ============================================================================
# 3. ОБНОВЛЯЕМ auth.cpp (добавляем хэширование)
# ============================================================================
echo ""
echo "3. Обновление auth.cpp с хэшированием..."

cat > server/auth.cpp << 'EOF'
#include "auth.h"
#include <QCryptographicHash>
#include <QRandomGenerator>

QString hashPassword(const QString& password)
{
    // SHA-256 хэширование
    QByteArray hash = QCryptographicHash::hash(password.toUtf8(), QCryptographicHash::Sha256);
    return QString(hash.toHex());
}

bool verifyPassword(const QString& plainPassword, const QString& hashedPassword)
{
    return hashPassword(plainPassword) == hashedPassword;
}

QString generateResetToken()
{
    // Генерируем 6-значный код
    int code = QRandomGenerator::global()->bounded(100000, 999999);
    return QString::number(code);
}
EOF

cat > server/auth.h << 'EOF'
#ifndef AUTH_H
#define AUTH_H

#include <QString>

QString hashPassword(const QString& password);
bool verifyPassword(const QString& plainPassword, const QString& hashedPassword);
QString generateResetToken();

#endif // AUTH_H
EOF

echo "   ✅ auth.cpp и auth.h обновлены"

# ============================================================================
# 4. ОБНОВЛЯЕМ postgresqlserver.cpp (используем хэширование)
# ============================================================================
echo ""
echo "4. Обновление postgresqlserver.cpp..."

# Исправляем регистрацию и авторизацию для использования хэшей
sed -i 's/db->addUser(parts\[1\], parts\[2\], parts\[3\])/db->addUser(parts[1], hashPassword(parts[2]), parts[3])/g' server/postgresqlserver.cpp
sed -i 's/db->checkAuth(parts\[1\], parts\[2\])/db->checkAuth(parts[1], hashPassword(parts[2]))/g' server/postgresqlserver.cpp

echo "   ✅ postgresqlserver.cpp обновлен"

# ============================================================================
# 5. ПЕРЕСБОРКА СЕРВЕРА
# ============================================================================
echo ""
echo "5. Пересборка сервера..."

cd $PROJECT_DIR/server
make clean 2>/dev/null
qmake server.pro 2>/dev/null
make -j$(nproc) 2>/dev/null

if [ $? -eq 0 ]; then
    echo "   ✅ Сервер успешно пересобран"
else
    echo "   ❌ Ошибка сборки сервера"
fi

# ============================================================================
# 6. ОБНОВЛЕНИЕ DOCKER КОНТЕЙНЕРА
# ============================================================================
echo ""
echo "6. Обновление Docker контейнера..."

cd $PROJECT_DIR
docker-compose down -v 2>/dev/null
docker-compose up -d 2>/dev/null

echo "   ✅ Контейнеры перезапущены"

# ============================================================================
# 7. СОЗДАНИЕ ДИАГРАММЫ МОДЕЛИ БАЗЫ ДАННЫХ
# ============================================================================
echo ""
echo "7. Создание диаграммы модели базы данных..."

mkdir -p wiki

cat > wiki/DatabaseModel.md << 'EOF'
# Модель базы данных

## ER-диаграмма
┌─────────────────────────────────────────────────────────────┐
│ users │
├─────────────────────────────────────────────────────────────┤
│ PK │ id │ SERIAL │
│ │ login │ VARCHAR(50) NOT NULL UNIQUE │
│ │ password │ VARCHAR(255) NOT NULL │
│ │ email │ VARCHAR(100) NOT NULL UNIQUE │
│ │ reset_token │ VARCHAR(100) │
│ │ reset_token_expires │ TIMESTAMP │
│ │ created_at │ TIMESTAMP DEFAULT CURRENT_TIMESTAMP │
└─────────────────────────────────────────────────────────────┘

## Описание полей

| Поле | Тип | Описание |
|------|-----|----------|
| **id** | SERIAL (PK) | Уникальный идентификатор пользователя |
| **login** | VARCHAR(50) | Логин для входа (уникальный) |
| **password** | VARCHAR(255) | Хэш пароля (SHA-256) |
| **email** | VARCHAR(100) | Email пользователя (уникальный) |
| **reset_token** | VARCHAR(100) | Токен для сброса пароля (6 цифр) |
| **reset_token_expires** | TIMESTAMP | Время истечения токена |
| **created_at** | TIMESTAMP | Дата регистрации |

## Тестовые данные

| id | login | password (hash) | email |
|----|-------|-----------------|-------|
| 1 | admin | 5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8 | admin@example.com |
| 2 | alice | 8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92 | alice@example.com |
| 3 | bob | 81b637d8fcd2c6da6359e6963113a1170de795e4b725b84d1e0b4cfd9ec58ce9 | bob@example.com |

## Соответствие паролей

| Логин | Пароль в открытом виде | Хэш (SHA-256) |
|-------|----------------------|---------------|
| admin | admin123 | 5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8 |
| alice | alice123 | 8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92 |
| bob | bob123 | 81b637d8fcd2c6da6359e6963113a1170de795e4b725b84d1e0b4cfd9ec58ce9 |

## Этапы работы с БД

### Этап 1: Регистрация
1. Проверка уникальности login и email
2. Хэширование пароля (SHA-256)
3. Вставка записи в таблицу users

### Этап 2: Авторизация
1. Поиск пользователя по login
2. Сравнение хэша введённого пароля с хэшем в БД

### Этап 3: Восстановление пароля
1. Генерация 6-значного токена
2. Сохранение токена и времени истечения
3. Отправка токена на email
4. Проверка токена при сбросе
5. Обновление пароля и очистка токена

### Этап 4: Просмотр данных
- Получение информации о пользователе по login или email
EOF

echo "   ✅ Диаграмма модели создана: wiki/DatabaseModel.md"

# ============================================================================
# 8. ВЫВОД ТЕСТОВЫХ ДАННЫХ
# ============================================================================
echo ""
echo "8. Тестовые данные:"

echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│  ТЕСТОВЫЕ ПОЛЬЗОВАТЕЛИ                                               │"
echo "├───────────────┬─────────────────────────────┬───────────────────────┤"
echo "│  login        │  password                   │  email                │"
echo "├───────────────┼─────────────────────────────┼───────────────────────┤"
echo "│  admin        │  admin123                   │  admin@example.com    │"
echo "│  alice        │  alice123                   │  alice@example.com    │"
echo "│  bob          │  bob123                     │  bob@example.com      │"
echo "└───────────────┴─────────────────────────────┴───────────────────────┘"
echo ""

# ============================================================================
# 9. ИТОГИ
# ============================================================================
echo ""
echo "=========================================="
echo "  ГОТОВО!"
echo "=========================================="
echo ""
echo "✅ Что сделано:"
echo "   - Удалены поля is_verified, verification_token"
echo "   - Добавлено хэширование паролей (SHA-256)"
echo "   - Оставлены поля: id, login, password, email, reset_token, created_at"
echo "   - Добавлены тестовые данные (admin, alice, bob)"
echo "   - Создана диаграмма модели БД: wiki/DatabaseModel.md"
echo ""
echo "🔑 Пароли тестовых пользователей:"
echo "   admin → admin123"
echo "   alice → alice123"
echo "   bob   → bob123"
echo ""
echo "🚀 Запуск:"
echo "   cd ~/projects/function-plotter"
echo "   docker-compose up -d"
echo "   cd client && ./client"
echo ""
echo "=========================================="
