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
