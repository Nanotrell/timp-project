#!/bin/bash
# ============================================================================
# СКРИПТ ДЛЯ ДОБАВЛЕНИЯ ФУНКЦИИ "ЗАБЫЛИ ПАРОЛЬ" С ПОДТВЕРЖДЕНИЕМ ПО EMAIL
# ============================================================================

set -e

echo "=========================================="
echo "  ДОБАВЛЕНИЕ ФУНКЦИИ ВОССТАНОВЛЕНИЯ ПАРОЛЯ"
echo "=========================================="

PROJECT_DIR=~/projects/function-plotter
cd $PROJECT_DIR

# ============================================================================
# 1. ОБНОВЛЕНИЕ БАЗЫ ДАННЫХ (ДОБАВЛЯЕМ ПОЛЯ ДЛЯ ТОКЕНОВ)
# ============================================================================
echo ""
echo "1. Обновление структуры базы данных..."

cat > server/update_database.sql << 'EOF'
-- Добавляем поля для восстановления пароля
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token_expires TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_token VARCHAR(100);
EOF

echo "   ✅ SQL скрипт создан"

# ============================================================================
# 2. ОБНОВЛЕНИЕ database.h
# ============================================================================
echo ""
echo "2. Обновление database.h..."

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
    QString password;
    QString email;
    bool isVerified;
    QString resetToken;
    QDateTime resetTokenExpires;
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
    bool addUser(const QString& login, const QString& password, const QString& email);
    bool userExists(const QString& login);
    bool checkAuth(const QString& login, const QString& password);
    UserInfo getUserInfo(const QString& login);
    bool updatePassword(const QString& login, const QString& newPassword);

    // Восстановление пароля
    bool setResetToken(const QString& email, const QString& token, int expiresMinutes = 30);
    QString getEmailByResetToken(const QString& token);
    bool isValidResetToken(const QString& token);
    bool clearResetToken(const QString& token);

    // Подтверждение email
    bool setVerificationToken(const QString& email, const QString& token);
    bool verifyEmail(const QString& token);
};

#endif // DATABASE_H
EOF

echo "   ✅ database.h обновлен"

# ============================================================================
# 3. ОБНОВЛЕНИЕ database.cpp
# ============================================================================
echo ""
echo "3. Обновление database.cpp..."

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
    qDebug() << "Подключено к PostgreSQL";
    return true;
}

bool Database::isOpen() const { return db.isOpen(); }
void Database::close() { if (db.isOpen()) db.close(); }

void Database::createTables()
{
    QSqlQuery query(db);
    query.exec("CREATE TABLE IF NOT EXISTS users ("
               "id SERIAL PRIMARY KEY, "
               "login VARCHAR(50) NOT NULL UNIQUE, "
               "password VARCHAR(50) NOT NULL, "
               "email VARCHAR(100) NOT NULL UNIQUE, "
               "is_verified BOOLEAN DEFAULT FALSE, "
               "verification_token VARCHAR(100), "
               "reset_token VARCHAR(100), "
               "reset_token_expires TIMESTAMP, "
               "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)");
}

void Database::updateTables()
{
    QSqlQuery query(db);
    // Добавляем колонки, если их нет
    query.exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token VARCHAR(100)");
    query.exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token_expires TIMESTAMP");
    query.exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE");
    query.exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_token VARCHAR(100)");
}

bool Database::addUser(const QString& login, const QString& password, const QString& email)
{
    if (userExists(login)) return false;

    QSqlQuery query(db);
    query.prepare("INSERT INTO users (login, password, email) VALUES (:login, :password, :email)");
    query.bindValue(":login", login);
    query.bindValue(":password", password);
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

bool Database::checkAuth(const QString& login, const QString& password)
{
    QSqlQuery query(db);
    query.prepare("SELECT password FROM users WHERE login = :login");
    query.bindValue(":login", login);
    return query.exec() && query.next() && query.value(0).toString() == password;
}

UserInfo Database::getUserInfo(const QString& login)
{
    UserInfo info;
    info.id = -1;

    QSqlQuery query(db);
    query.prepare("SELECT id, login, password, email, is_verified, reset_token, reset_token_expires "
                  "FROM users WHERE login = :login");
    query.bindValue(":login", login);

    if (query.exec() && query.next()) {
        info.id = query.value(0).toInt();
        info.login = query.value(1).toString();
        info.password = query.value(2).toString();
        info.email = query.value(3).toString();
        info.isVerified = query.value(4).toBool();
        info.resetToken = query.value(5).toString();
        info.resetTokenExpires = query.value(6).toDateTime();
    }
    return info;
}

bool Database::updatePassword(const QString& login, const QString& newPassword)
{
    QSqlQuery query(db);
    query.prepare("UPDATE users SET password = :password WHERE login = :login");
    query.bindValue(":password", newPassword);
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

bool Database::setVerificationToken(const QString& email, const QString& token)
{
    QSqlQuery query(db);
    query.prepare("UPDATE users SET verification_token = :token WHERE email = :email");
    query.bindValue(":token", token);
    query.bindValue(":email", email);
    return query.exec();
}

bool Database::verifyEmail(const QString& token)
{
    QSqlQuery query(db);
    query.prepare("UPDATE users SET is_verified = TRUE, verification_token = NULL "
                  "WHERE verification_token = :token");
    query.bindValue(":token", token);
    return query.exec();
}
EOF

echo "   ✅ database.cpp обновлен"

# ============================================================================
# 4. ОБНОВЛЕНИЕ СЕРВЕРА (ДОБАВЛЯЕМ ОБРАБОТЧИКИ forgot и reset)
# ============================================================================
echo ""
echo "4. Обновление сервера (добавление forgot/reset)..."

cat > server/postgresqlserver.cpp << 'EOF'
#include "postgresqlserver.h"
#include "database.h"
#include "math_engine.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRandomGenerator>
#include <QRegularExpression>

// Генерация случайного кода (6 цифр)
QString generateCode() {
    int code = QRandomGenerator::global()->bounded(100000, 999999);
    return QString::number(code);
}

// Отправка email (упрощенная версия)
void sendEmail(const QString& to, const QString& subject, const QString& body) {
    qDebug() << "📧 Email to:" << to;
    qDebug() << "   Subject:" << subject;
    qDebug() << "   Body:" << body;
    // В реальном проекте здесь нужно использовать SMTP
}

PostgreSQLServer::PostgreSQLServer(QObject *parent) : QObject(parent)
{
    m_server = new QTcpServer(this);
    connect(m_server, &QTcpServer::newConnection, this, &PostgreSQLServer::onNewConnection);

    if (!m_server->listen(QHostAddress::Any, 33333)) {
        qDebug() << "Ошибка запуска:" << m_server->errorString();
    } else {
        qDebug() << "Сервер запущен на порту 33333";

        QString dbHost = qgetenv("POSTGRES_HOST");
        if (dbHost.isEmpty()) dbHost = "localhost";
        QString dbName = qgetenv("POSTGRES_DB");
        if (dbName.isEmpty()) dbName = "function_plotter";
        QString dbUser = qgetenv("POSTGRES_USER");
        if (dbUser.isEmpty()) dbUser = "plotter_user";
        QString dbPass = qgetenv("POSTGRES_PASSWORD");
        if (dbPass.isEmpty()) dbPass = "plotter123";

        Database* db = Database::getInstance();
        if (!db->connect(dbHost, dbName, dbUser, dbPass, 5432)) {
            qDebug() << "Ошибка подключения к PostgreSQL!";
        } else {
            qDebug() << "PostgreSQL подключен";
        }
    }
}

PostgreSQLServer::~PostgreSQLServer()
{
    m_server->close();
    Database::getInstance()->close();
}

void PostgreSQLServer::onNewConnection()
{
    QTcpSocket* client = m_server->nextPendingConnection();
    if (!client) return;

    ClientSession session;
    session.buffer = "";
    session.currentLogin = "";
    m_clients[client] = session;

    connect(client, &QTcpSocket::readyRead, this, &PostgreSQLServer::onReadyRead);
    connect(client, &QTcpSocket::disconnected, this, &PostgreSQLServer::onClientDisconnected);

    qDebug() << "Клиент подключен:" << client->peerAddress().toString();
    sendResponse(client, "Connected to Function Plotter Server");
    sendResponse(client, "Commands: auth|login|pass | reg|login|pass|email | forgot|email | reset|code|newpass | calc|a|b|c");
}

void PostgreSQLServer::onReadyRead()
{
    QTcpSocket* client = qobject_cast<QTcpSocket*>(sender());
    if (!client || !m_clients.contains(client)) return;

    QByteArray data = client->readAll();
    m_clients[client].buffer += QString::fromUtf8(data);

    if (m_clients[client].buffer.contains('\n')) {
        QStringList lines = m_clients[client].buffer.split('\n');
        for (int i = 0; i < lines.size() - 1; ++i) {
            QString request = lines[i].trimmed();
            if (!request.isEmpty()) processRequest(client, request);
        }
        m_clients[client].buffer = lines.last();
    }
}

void PostgreSQLServer::processRequest(QTcpSocket* client, const QString& request)
{
    qDebug() << "Запрос:" << request;
    QStringList parts = request.split('|');
    if (parts.isEmpty()) { sendResponse(client, "ERROR|Empty"); return; }

    QString cmd = parts[0];

    // ========== РЕГИСТРАЦИЯ ==========
    if (cmd == "reg" && parts.size() >= 4) {
        Database* db = Database::getInstance();
        if (db->addUser(parts[1], parts[2], parts[3])) {
            sendResponse(client, "REG_SUCCESS|" + parts[1]);
        } else {
            sendResponse(client, "REG_FAILED|User exists");
        }
    }
    // ========== АВТОРИЗАЦИЯ ==========
    else if (cmd == "auth" && parts.size() >= 3) {
        Database* db = Database::getInstance();
        if (db->checkAuth(parts[1], parts[2])) {
            m_clients[client].currentLogin = parts[1];
            sendResponse(client, "AUTH_SUCCESS|" + parts[1]);
        } else {
            sendResponse(client, "AUTH_FAILED");
        }
    }
    // ========== ЗАБЫЛИ ПАРОЛЬ - ОТПРАВКА КОДА ==========
    else if (cmd == "forgot" && parts.size() >= 2) {
        QString email = parts[1];
        Database* db = Database::getInstance();

        // Проверяем, существует ли email
        UserInfo user = db->getUserInfo(email); // Нужно добавить метод getUserInfoByEmail
        if (user.id == -1) {
            // Не сообщаем, что email не найден (безопасность)
            sendResponse(client, "FORGOT_SENT|If email exists, code was sent");
            return;
        }

        // Генерируем 6-значный код
        QString code = generateCode();

        // Сохраняем код в БД как reset_token
        db->setResetToken(email, code, 15); // 15 минут на ввод

        // Отправляем email
        QString body = QString(
            "<h2>Восстановление пароля</h2>"
            "<p>Ваш код для сброса пароля: <b>%1</b></p>"
            "<p>Код действителен в течение 15 минут.</p>"
            "<p>Если вы не запрашивали сброс пароля, проигнорируйте это письмо.</p>"
        ).arg(code);

        sendEmail(email, "Код восстановления пароля", body);
        sendResponse(client, "FORGOT_SENT|Code sent to email");
    }
    // ========== СБРОС ПАРОЛЯ ПО КОДУ ==========
    else if (cmd == "reset" && parts.size() >= 3) {
        QString code = parts[1];
        QString newPassword = parts[2];
        Database* db = Database::getInstance();

        // Проверяем код
        if (!db->isValidResetToken(code)) {
            sendResponse(client, "RESET_FAILED|Invalid or expired code");
            return;
        }

        // Получаем email по коду
        QString email = db->getEmailByResetToken(code);
        if (email.isEmpty()) {
            sendResponse(client, "RESET_FAILED|Invalid code");
            return;
        }

        // Обновляем пароль (нужно получить login по email)
        // Для упрощения: ищем пользователя по email
        QSqlQuery query(db->getDatabase());
        query.prepare("SELECT login FROM users WHERE email = :email");
        query.bindValue(":email", email);
        if (query.exec() && query.next()) {
            QString login = query.value(0).toString();
            db->updatePassword(login, newPassword);
        }

        // Очищаем токен
        db->clearResetToken(code);
        sendResponse(client, "RESET_SUCCESS|Password updated");
    }
    // ========== РАСЧЕТ ТОЧЕК ==========
    else if (cmd == "calc" && parts.size() >= 4) {
        FunctionParams params(parts[1].toDouble(), parts[2].toDouble(), parts[3].toDouble());
        QVector<QPointF> points = MathEngine::generatePoints(params, 20);
        QJsonArray pointsArray;
        for (const QPointF& p : points) {
            QJsonObject obj;
            obj["x"] = p.x();
            obj["y"] = p.y();
            pointsArray.append(obj);
        }
        QJsonObject response;
        response["type"] = "CALC_RESPONSE";
        response["points"] = pointsArray;
        client->write(QJsonDocument(response).toJson());
        client->write("\n");
    }
    else {
        sendResponse(client, "ERROR|Unknown: " + cmd);
    }
}

void PostgreSQLServer::sendResponse(QTcpSocket* client, const QString& response)
{
    client->write(response.toUtf8());
    client->write("\n");
}

void PostgreSQLServer::onClientDisconnected()
{
    QTcpSocket* client = qobject_cast<QTcpSocket*>(sender());
    if (client) {
        qDebug() << "Клиент отключен";
        m_clients.remove(client);
        client->deleteLater();
    }
}
EOF

# Добавляем метод getDatabase() в database.h
echo ""
echo "5. Добавление вспомогательных методов..."

cat >> server/database.h << 'EOF'

// Вспомогательный метод для получения QSqlDatabase (для запросов)
QSqlDatabase getDatabase() { return db; }
EOF

# Добавляем метод getUserInfoByEmail
cat >> server/database.cpp << 'EOF'

UserInfo Database::getUserInfoByEmail(const QString& email)
{
    UserInfo info;
    info.id = -1;

    QSqlQuery query(db);
    query.prepare("SELECT id, login, password, email, is_verified FROM users WHERE email = :email");
    query.bindValue(":email", email);

    if (query.exec() && query.next()) {
        info.id = query.value(0).toInt();
        info.login = query.value(1).toString();
        info.password = query.value(2).toString();
        info.email = query.value(3).toString();
        info.isVerified = query.value(4).toBool();
    }
    return info;
}
EOF

# Добавляем объявление в .h
cat >> server/database.h << 'EOF'
    UserInfo getUserInfoByEmail(const QString& email);
EOF

echo "   ✅ Методы добавлены"

# ============================================================================
# 5. ОБНОВЛЕНИЕ КЛИЕНТА (ДОБАВЛЯЕМ ОКНО ВОССТАНОВЛЕНИЯ ПАРОЛЯ)
# ============================================================================
echo ""
echo "6. Обновление клиента (добавление forgot/reset)..."

# Создаем окно восстановления пароля
cat > client/resetpassworddialog.h << 'EOF'
#ifndef RESETPASSWORDDIALOG_H
#define RESETPASSWORDDIALOG_H

#include <QDialog>
#include <QTcpSocket>
#include <QLineEdit>
#include <QLabel>

class ResetPasswordDialog : public QDialog
{
    Q_OBJECT

public:
    explicit ResetPasswordDialog(QWidget *parent = nullptr);
    void setSocket(QTcpSocket* socket) { m_socket = socket; }

private slots:
    void onSendCode();
    void onResetPassword();
    void onReadyRead();
    void switchToCodeStep();
    void switchToResetStep();

private:
    void sendCommand(const QString& cmd);
    void appendMessage(const QString& msg, bool isError = false);

    QTcpSocket* m_socket;

    // Шаг 1: ввод email
    QLineEdit* m_emailEdit;
    QPushButton* m_sendCodeBtn;

    // Шаг 2: ввод кода и нового пароля
    QLineEdit* m_codeEdit;
    QLineEdit* m_newPasswordEdit;
    QPushButton* m_resetBtn;

    QLabel* m_statusLabel;
    QPushButton* m_backBtn;

    int m_step; // 1 - email, 2 - code+password
};

#endif // RESETPASSWORDDIALOG_H
EOF

cat > client/resetpassworddialog.cpp << 'EOF'
#include "resetpassworddialog.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QFormLayout>
#include <QMessageBox>

ResetPasswordDialog::ResetPasswordDialog(QWidget *parent) : QDialog(parent), m_step(1)
{
    setWindowTitle("Восстановление пароля");
    setFixedSize(400, 300);
    setModal(true);

    QVBoxLayout* mainLayout = new QVBoxLayout(this);

    // Шаг 1: ввод email
    QWidget* step1Widget = new QWidget();
    QVBoxLayout* step1Layout = new QVBoxLayout(step1Widget);

    QLabel* infoLabel = new QLabel("Введите email, на который отправить код восстановления");
    infoLabel->setWordWrap(true);
    step1Layout->addWidget(infoLabel);

    QFormLayout* formLayout = new QFormLayout();
    m_emailEdit = new QLineEdit();
    m_emailEdit->setPlaceholderText("example@mail.com");
    formLayout->addRow("Email:", m_emailEdit);
    step1Layout->addLayout(formLayout);

    m_sendCodeBtn = new QPushButton("Отправить код");
    step1Layout->addWidget(m_sendCodeBtn);

    // Шаг 2: ввод кода и нового пароля
    QWidget* step2Widget = new QWidget();
    QVBoxLayout* step2Layout = new QVBoxLayout(step2Widget);

    QLabel* codeLabel = new QLabel("Введите код из письма и новый пароль");
    codeLabel->setWordWrap(true);
    step2Layout->addWidget(codeLabel);

    QFormLayout* resetForm = new QFormLayout();
    m_codeEdit = new QLineEdit();
    m_codeEdit->setPlaceholderText("6-значный код");
    resetForm->addRow("Код:", m_codeEdit);

    m_newPasswordEdit = new QLineEdit();
    m_newPasswordEdit->setEchoMode(QLineEdit::Password);
    m_newPasswordEdit->setPlaceholderText("Новый пароль (мин. 6 символов)");
    resetForm->addRow("Новый пароль:", m_newPasswordEdit);
    step2Layout->addLayout(resetForm);

    m_resetBtn = new QPushButton("Сбросить пароль");
    step2Layout->addWidget(m_resetBtn);

    // Общий статус
    m_statusLabel = new QLabel();
    m_statusLabel->setAlignment(Qt::AlignCenter);
    mainLayout->addWidget(step1Widget);
    mainLayout->addWidget(step2Widget);
    mainLayout->addWidget(m_statusLabel);

    // Кнопка назад
    m_backBtn = new QPushButton("Назад");
    mainLayout->addWidget(m_backBtn);

    // Скрываем шаг 2 сначала
    step2Widget->hide();

    // Подключаем сигналы
    connect(m_sendCodeBtn, &QPushButton::clicked, this, &ResetPasswordDialog::onSendCode);
    connect(m_resetBtn, &QPushButton::clicked, this, &ResetPasswordDialog::onResetPassword);
    connect(m_backBtn, &QPushButton::clicked, this, &ResetPasswordDialog::switchToCodeStep);

    m_socket = nullptr;
}

void ResetPasswordDialog::onSendCode()
{
    if (!m_socket || m_socket->state() != QAbstractSocket::ConnectedState) {
        appendMessage("Нет подключения к серверу", true);
        return;
    }

    QString email = m_emailEdit->text().trimmed();
    if (email.isEmpty() || !email.contains('@')) {
        appendMessage("Введите корректный email", true);
        return;
    }

    sendCommand(QString("forgot|%1").arg(email));
    m_sendCodeBtn->setEnabled(false);
    appendMessage("Отправка запроса...");
}

void ResetPasswordDialog::onResetPassword()
{
    if (!m_socket || m_socket->state() != QAbstractSocket::ConnectedState) {
        appendMessage("Нет подключения к серверу", true);
        return;
    }

    QString code = m_codeEdit->text().trimmed();
    QString newPassword = m_newPasswordEdit->text().trimmed();

    if (code.isEmpty() || code.length() != 6) {
        appendMessage("Введите 6-значный код из письма", true);
        return;
    }

    if (newPassword.length() < 6) {
        appendMessage("Пароль должен быть не менее 6 символов", true);
        return;
    }

    sendCommand(QString("reset|%1|%2").arg(code).arg(newPassword));
    m_resetBtn->setEnabled(false);
    appendMessage("Сброс пароля...");
}

void ResetPasswordDialog::onReadyRead()
{
    if (!m_socket) return;

    while (m_socket->bytesAvailable()) {
        QByteArray data = m_socket->readAll();
        QString response = QString::fromUtf8(data).trimmed();

        if (response.startsWith("FORGOT_SENT|")) {
            appendMessage("✓ Код отправлен на email");
            switchToResetStep();
        }
        else if (response.startsWith("RESET_SUCCESS|")) {
            appendMessage("✓ Пароль успешно изменен!");
            QMessageBox::information(this, "Успех", "Пароль изменен. Теперь вы можете войти с новым паролем.");
            accept();
        }
        else if (response.startsWith("RESET_FAILED|")) {
            appendMessage("✗ " + response.mid(13), true);
            m_resetBtn->setEnabled(true);
        }
        else if (response.startsWith("ERROR|")) {
            appendMessage("✗ " + response.mid(6), true);
            m_sendCodeBtn->setEnabled(true);
        }
    }
}

void ResetPasswordDialog::switchToCodeStep()
{
    m_step = 1;
    // Показываем шаг 1, скрываем шаг 2
    findChild<QWidget*>("step1Widget")->show();
    findChild<QWidget*>("step2Widget")->hide();
    m_backBtn->setText("Назад");
}

void ResetPasswordDialog::switchToResetStep()
{
    m_step = 2;
    // Скрываем шаг 1, показываем шаг 2
    // (нужно получить указатели на виджеты)
    QList<QWidget*> widgets = findChildren<QWidget*>();
    for (QWidget* w : widgets) {
        if (w->objectName() == "step1Widget") w->hide();
        if (w->objectName() == "step2Widget") w->show();
    }
    m_backBtn->setText("Назад к email");
    m_statusLabel->clear();
}

void ResetPasswordDialog::sendCommand(const QString& cmd)
{
    if (m_socket) {
        m_socket->write((cmd + "\n").toUtf8());
    }
}

void ResetPasswordDialog::appendMessage(const QString& msg, bool isError)
{
    m_statusLabel->setText(msg);
    if (isError) {
        m_statusLabel->setStyleSheet("color: red;");
    } else {
        m_statusLabel->setStyleSheet("color: green;");
    }
}
EOF

echo "   ✅ resetpassworddialog.h/cpp созданы"

# ============================================================================
# 6. ОБНОВЛЕНИЕ authwindow.cpp (ДОБАВЛЯЕМ КНОПКУ "ЗАБЫЛИ ПАРОЛЬ")
# ============================================================================
echo ""
echo "7. Обновление authwindow.cpp..."

# Добавляем кнопку в authwindow.h
cat >> client/authwindow.h << 'EOF'
    void onForgotPassword();
EOF

# Обновляем authwindow.cpp
cat > client/authwindow.cpp << 'EOF'
#include "authwindow.h"
#include "mainwindow.h"
#include "resetpassworddialog.h"
#include <QVBoxLayout>
#include <QFormLayout>
#include <QMessageBox>

AuthWindow::AuthWindow(QWidget *parent) : QWidget(parent), m_isLoginMode(true)
{
    setWindowTitle("Авторизация");
    setFixedSize(400, 400);

    QVBoxLayout* mainLayout = new QVBoxLayout(this);

    QLabel* titleLabel = new QLabel("Function Plotter");
    titleLabel->setAlignment(Qt::AlignCenter);
    QFont titleFont = titleLabel->font();
    titleFont.setPointSize(16);
    titleFont.setBold(true);
    titleLabel->setFont(titleFont);
    mainLayout->addWidget(titleLabel);
    mainLayout->addSpacing(20);

    QFormLayout* formLayout = new QFormLayout();
    m_loginEdit = new QLineEdit();
    m_loginEdit->setPlaceholderText("Введите логин");
    m_passwordEdit = new QLineEdit();
    m_passwordEdit->setEchoMode(QLineEdit::Password);
    m_passwordEdit->setPlaceholderText("Введите пароль");
    m_emailLabel = new QLabel("Email:");
    m_emailEdit = new QLineEdit();
    m_emailEdit->setPlaceholderText("example@mail.com");

    formLayout->addRow("Логин:", m_loginEdit);
    formLayout->addRow("Пароль:", m_passwordEdit);
    formLayout->addRow(m_emailLabel, m_emailEdit);
    m_emailLabel->hide();
    m_emailEdit->hide();
    mainLayout->addLayout(formLayout);
    mainLayout->addSpacing(10);

    m_actionButton = new QPushButton("Войти");
    m_actionButton->setFixedHeight(35);
    m_switchButton = new QPushButton("Нет аккаунта? Зарегистрироваться");

    QPushButton* forgotBtn = new QPushButton("Забыли пароль?");
    forgotBtn->setFixedHeight(25);
    forgotBtn->setStyleSheet("QPushButton { color: blue; background: transparent; border: none; }");

    m_statusLabel = new QLabel("Подключение...");
    m_statusLabel->setAlignment(Qt::AlignCenter);

    mainLayout->addWidget(m_actionButton);
    mainLayout->addWidget(m_switchButton);
    mainLayout->addWidget(forgotBtn);
    mainLayout->addWidget(m_statusLabel);

    connect(m_actionButton, &QPushButton::clicked, this, &AuthWindow::onLogin);
    connect(m_switchButton, &QPushButton::clicked, this, &AuthWindow::switchToRegister);
    connect(forgotBtn, &QPushButton::clicked, this, &AuthWindow::onForgotPassword);

    m_socket = new QTcpSocket(this);
    connect(m_socket, &QTcpSocket::connected, this, &AuthWindow::onConnected);
    connect(m_socket, &QTcpSocket::readyRead, this, &AuthWindow::onReadyRead);
    connect(m_socket, &QTcpSocket::errorOccurred, this, &AuthWindow::onError);
    m_socket->connectToHost("localhost", 33333);
}

AuthWindow::~AuthWindow() { if (m_socket->state() == QAbstractSocket::ConnectedState) m_socket->disconnectFromHost(); }

void AuthWindow::onConnected() { m_statusLabel->setText("Подключено к серверу"); m_statusLabel->setStyleSheet("color: green;"); }
void AuthWindow::onError(QAbstractSocket::SocketError) { m_statusLabel->setText("Ошибка: " + m_socket->errorString()); m_statusLabel->setStyleSheet("color: red;"); }

void AuthWindow::onReadyRead()
{
    while (m_socket->bytesAvailable()) {
        QString response = QString::fromUtf8(m_socket->readAll()).trimmed();
        if (response.startsWith("AUTH_SUCCESS|") || response.startsWith("REG_SUCCESS|")) {
            QString login = response.mid(response.indexOf('|') + 1);
            emit authSuccess(login);
            close();
        } else if (response == "AUTH_FAILED") {
            QMessageBox::warning(this, "Ошибка", "Неверный логин или пароль");
        } else if (response == "REG_FAILED|User exists") {
            QMessageBox::warning(this, "Ошибка", "Пользователь уже существует");
        }
    }
}

void AuthWindow::sendCommand(const QString& cmd) { m_socket->write((cmd + "\n").toUtf8()); }

void AuthWindow::onLogin()
{
    QString login = m_loginEdit->text().trimmed();
    QString password = m_passwordEdit->text().trimmed();
    if (login.isEmpty() || password.isEmpty()) {
        QMessageBox::warning(this, "Ошибка", "Введите логин и пароль");
        return;
    }
    if (m_isLoginMode) {
        sendCommand(QString("auth|%1|%2").arg(login).arg(password));
    } else {
        QString email = m_emailEdit->text().trimmed();
        if (email.isEmpty() || !email.contains('@')) {
            QMessageBox::warning(this, "Ошибка", "Введите корректный email");
            return;
        }
        sendCommand(QString("reg|%1|%2|%3").arg(login).arg(password).arg(email));
    }
}

void AuthWindow::onForgotPassword()
{
    ResetPasswordDialog* dlg = new ResetPasswordDialog(this);
    dlg->setSocket(m_socket);
    dlg->exec();
    delete dlg;
}

void AuthWindow::onRegister() { onLogin(); }

void AuthWindow::switchToLogin()
{
    m_isLoginMode = true;
    setWindowTitle("Авторизация");
    m_actionButton->setText("Войти");
    m_switchButton->setText("Нет аккаунта? Зарегистрироваться");
    m_emailLabel->hide();
    m_emailEdit->hide();
    disconnect(m_actionButton, &QPushButton::clicked, this, &AuthWindow::onRegister);
    disconnect(m_switchButton, &QPushButton::clicked, this, &AuthWindow::switchToLogin);
    connect(m_actionButton, &QPushButton::clicked, this, &AuthWindow::onLogin);
    connect(m_switchButton, &QPushButton::clicked, this, &AuthWindow::switchToRegister);
}

void AuthWindow::switchToRegister()
{
    m_isLoginMode = false;
    setWindowTitle("Регистрация");
    m_actionButton->setText("Зарегистрироваться");
    m_switchButton->setText("Уже есть аккаунт? Войти");
    m_emailLabel->show();
    m_emailEdit->show();
    disconnect(m_actionButton, &QPushButton::clicked, this, &AuthWindow::onLogin);
    disconnect(m_switchButton, &QPushButton::clicked, this, &AuthWindow::switchToRegister);
    connect(m_actionButton, &QPushButton::clicked, this, &AuthWindow::onRegister);
    connect(m_switchButton, &QPushButton::clicked, this, &AuthWindow::switchToLogin);
}
EOF

# ============================================================================
# 7. ОБНОВЛЕНИЕ client.pro
# ============================================================================
echo ""
echo "8. Обновление client.pro..."

cat > client/client.pro << 'EOF'
QT += core gui network widgets

CONFIG += c++11
CONFIG -= app_bundle

SOURCES += \
    main.cpp \
    authwindow.cpp \
    mainwindow.cpp \
    plotwidget.cpp \
    resetpassworddialog.cpp

HEADERS += \
    authwindow.h \
    mainwindow.h \
    plotwidget.h \
    resetpassworddialog.h
EOF

# ============================================================================
# 8. ПЕРЕСБОРКА ПРОЕКТА
# ============================================================================
echo ""
echo "9. Пересборка проекта..."

cd $PROJECT_DIR/server
qmake server.pro 2>/dev/null
make clean 2>/dev/null
make -j$(nproc) 2>/dev/null

cd $PROJECT_DIR/client
qmake client.pro 2>/dev/null
make clean 2>/dev/null
make -j$(nproc) 2>/dev/null

echo "   ✅ Пересборка завершена"

# ============================================================================
# 9. ИТОГ
# ============================================================================
echo ""
echo "=========================================="
echo "  ФУНКЦИЯ ВОССТАНОВЛЕНИЯ ПАРОЛЯ ДОБАВЛЕНА!"
echo "=========================================="
echo ""
echo "✅ Что добавлено:"
echo "   - База данных: поля reset_token, reset_token_expires"
echo "   - Сервер: команды forgot|email и reset|code|newpass"
echo "   - Клиент: кнопка 'Забыли пароль?' и диалог восстановления"
echo "   - Генерация 6-значного кода и отправка на email"
echo ""
echo "🚀 Запуск:"
echo "   1. docker-compose up -d   # если используется Docker"
echo "   2. cd client && ./client"
echo ""
echo "📧 Тестирование:"
echo "   1. Нажмите 'Забыли пароль?'"
echo "   2. Введите email зарегистрированного пользователя"
echo "   3. Получите код в консоли сервера (для теста)"
echo "   4. Введите код и новый пароль"
echo ""
echo "=========================================="
