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
