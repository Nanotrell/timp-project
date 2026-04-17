#!/bin/bash
# ============================================================================
# ПОЛНЫЙ СКРИПТ: ИСПРАВЛЕНИЕ ОТПРАВКИ EMAIL ЧЕРЕЗ SMTP
# ============================================================================

set -e

PROJECT_DIR=~/projects/function-plotter-copy/timp-project
cd $PROJECT_DIR

echo "=========================================="
echo "  НАСТРОЙКА РЕАЛЬНОЙ ОТПРАВКИ EMAIL"
echo "=========================================="

# ============================================================================
# 1. ОБНОВЛЕНИЕ send_email.py
# ============================================================================
echo ""
echo "1. Обновление Python скрипта для отправки email..."

cat > server/send_email.py << 'EOF'
#!/usr/bin/env python3
import smtplib
import sys
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def send_email(to_email, subject, body):
    smtp_host = os.environ.get('SMTP_HOST', 'smtp.gmail.com')
    smtp_port = int(os.environ.get('SMTP_PORT', 587))
    smtp_user = os.environ.get('SMTP_USER', '')
    smtp_password = os.environ.get('SMTP_PASSWORD', '')
    from_email = os.environ.get('FROM_EMAIL', smtp_user)
    
    if not smtp_user or not smtp_password:
        print("ERROR: SMTP not configured")
        return False
    
    try:
        msg = MIMEMultipart()
        msg['From'] = from_email
        msg['To'] = to_email
        msg['Subject'] = subject
        msg.attach(MIMEText(body, 'html'))
        
        server = smtplib.SMTP(smtp_host, smtp_port)
        server.starttls()
        server.login(smtp_user, smtp_password)
        server.send_message(msg)
        server.quit()
        
        print("OK")
        return True
    except Exception as e:
        print(f"ERROR: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) >= 4:
        success = send_email(sys.argv[1], sys.argv[2], sys.argv[3])
        sys.exit(0 if success else 1)
    else:
        print("Usage: send_email.py to subject body")
        sys.exit(1)
EOF

chmod +x server/send_email.py
echo "   ✅ send_email.py обновлен"

# ============================================================================
# 2. ОБНОВЛЕНИЕ postgresqlserver.cpp
# ============================================================================
echo ""
echo "2. Обновление функции sendEmail в сервере..."

cat > server/postgresqlserver.cpp << 'EOF'
#include "postgresqlserver.h"
#include "database.h"
#include "math_engine.h"
#include "auth.h"
#include "email_config.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTcpSocket>
#include <QSslSocket>
#include <QRegularExpression>

// ========== ОТПРАВКА EMAIL ==========
void sendEmail(const QString& to, const QString& subject, const QString& body)
{
    qDebug() << "========================================";
    qDebug() << "📧 Email to:" << to;
    
    QRegularExpression re("(\\d{6})");
    QRegularExpressionMatch match = re.match(body);
    QString code = match.hasMatch() ? match.captured(1) : "???";
    qDebug() << "🔑 Код:" << code;
    
    QString smtpUser = qgetenv("SMTP_USER");
    if (smtpUser.isEmpty() || smtpUser == "your-email@gmail.com") {
        qDebug() << "⚠️ SMTP не настроен! Код для теста:" << code;
        qDebug() << "========================================";
        return;
    }
    
    QString cmd = QString("python3 /root/server/send_email.py \"%1\" \"%2\" \"%3\" 2>&1")
                      .arg(to, subject, body);
    
    FILE* pipe = popen(cmd.toUtf8(), "r");
    if (!pipe) {
        qDebug() << "⚠️ Не удалось запустить Python скрипт";
        return;
    }
    
    char buffer[256];
    QString result;
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        result += buffer;
    }
    int exitCode = pclose(pipe);
    
    if (exitCode == 0 && result.contains("OK")) {
        qDebug() << "✅ Email отправлен на" << to;
    } else {
        qDebug() << "⚠️ Ошибка отправки:" << result.trimmed();
        qDebug() << "⚠️ Используйте код для теста:" << code;
    }
    qDebug() << "========================================";
}

// ========== КОНСТРУКТОР ==========
PostgreSQLServer::PostgreSQLServer(QObject *parent) : QObject(parent)
{
    m_server = new QTcpServer(this);
    connect(m_server, &QTcpServer::newConnection, this, &PostgreSQLServer::onNewConnection);

    if (!m_server->listen(QHostAddress::Any, 33333)) {
        qDebug() << "Ошибка запуска:" << m_server->errorString();
    } else {
        qDebug() << "Сервер запущен на порту 33333";

        QString dbHost = qgetenv("POSTGRES_HOST");
        if (dbHost.isEmpty()) dbHost = "postgres";

        QString dbName = qgetenv("POSTGRES_DB");
        if (dbName.isEmpty()) dbName = "function_plotter";

        QString dbUser = qgetenv("POSTGRES_USER");
        if (dbUser.isEmpty()) dbUser = "plotter_user";

        QString dbPass = qgetenv("POSTGRES_PASSWORD");
        if (dbPass.isEmpty()) dbPass = "plotter123";

        int dbPort = qgetenv("POSTGRES_PORT").toInt();
        if (dbPort == 0) dbPort = 5432;

        Database* db = Database::getInstance();
        if (!db->connect(dbHost, dbName, dbUser, dbPass, dbPort)) {
            qDebug() << "Ошибка подключения к PostgreSQL!";
        } else {
            qDebug() << "PostgreSQL подключен";
        }
    }
}

PostgreSQLServer::~PostgreSQLServer()
{
    if (m_server) {
        m_server->close();
    }
    Database::getInstance()->close();
    qDebug() << "Сервер остановлен";
}

// ========== СЛОТЫ ==========
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
            if (!request.isEmpty()) {
                processRequest(client, request);
            }
        }
        m_clients[client].buffer = lines.last();
    }
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

// ========== ОБРАБОТКА ЗАПРОСОВ ==========
void PostgreSQLServer::processRequest(QTcpSocket* client, const QString& request)
{
    qDebug() << "Запрос:" << request;
    QStringList parts = request.split('|');
    if (parts.isEmpty()) {
        sendResponse(client, "ERROR|Empty");
        return;
    }
    
    QString cmd = parts[0];
    
    if (cmd == "reg" && parts.size() >= 4) {
        Database* db = Database::getInstance();
        if (db->addUser(parts[1], hashPassword(parts[2]), parts[3])) {
            sendResponse(client, "REG_SUCCESS|" + parts[1]);
        } else {
            sendResponse(client, "REG_FAILED|User exists");
        }
    }
    else if (cmd == "auth" && parts.size() >= 3) {
        Database* db = Database::getInstance();
        if (db->checkAuth(parts[1], hashPassword(parts[2]))) {
            m_clients[client].currentLogin = parts[1];
            sendResponse(client, "AUTH_SUCCESS|" + parts[1]);
        } else {
            sendResponse(client, "AUTH_FAILED");
        }
    }
    else if (cmd == "forgot" && parts.size() >= 2) {
        QString email = parts[1];
        Database* db = Database::getInstance();
        
        UserInfo user = db->getUserInfoByEmail(email);
        if (user.id == -1) {
            sendResponse(client, "FORGOT_SENT|If email exists, code was sent");
            return;
        }
        
        QString code = generateResetToken();
        db->setResetToken(email, code, 15);
        
        QString body = QString(
            "<h2>Восстановление пароля</h2>"
            "<p>Ваш код: <b>%1</b></p>"
            "<p>Действителен 15 минут.</p>"
        ).arg(code);
        
        sendEmail(email, "Код восстановления пароля", body);
        sendResponse(client, "FORGOT_SENT|Code sent to email");
    }
    else if (cmd == "reset" && parts.size() >= 3) {
        QString code = parts[1];
        QString newPassword = parts[2];
        Database* db = Database::getInstance();
        
        if (!db->isValidResetToken(code)) {
            sendResponse(client, "RESET_FAILED|Invalid code");
            return;
        }
        
        QString email = db->getEmailByResetToken(code);
        UserInfo user = db->getUserInfoByEmail(email);
        if (user.id != -1) {
            db->updatePassword(user.login, hashPassword(newPassword));
        }
        
        db->clearResetToken(code);
        sendResponse(client, "RESET_SUCCESS|Password updated");
    }
    else if (cmd == "calc" && parts.size() >= 4) {
        double a = parts[1].toDouble();
        double b = parts[2].toDouble();
        double c = parts[3].toDouble();
        
        FunctionParams params(a, b, c);
        
        QVector<QPointF> graphPoints = MathEngine::generatePoints(params, 200);
        QJsonArray graphArray;
        for (const QPointF& p : graphPoints) {
            QJsonObject obj;
            obj["x"] = p.x();
            obj["y"] = p.y();
            graphArray.append(obj);
        }
        
        QVector<QPointF> tablePoints = MathEngine::generateDisplayPoints(params);
        QJsonArray tableArray;
        for (const QPointF& p : tablePoints) {
            QJsonObject obj;
            obj["x"] = p.x();
            obj["y"] = p.y();
            tableArray.append(obj);
        }
        
        QJsonObject response;
        response["type"] = "CALC_RESPONSE";
        response["graphPoints"] = graphArray;
        response["tablePoints"] = tableArray;
        
        client->write(QJsonDocument(response).toJson());
        client->write("\n");
        qDebug() << "📊 Отправлено:" << graphPoints.size() << "точек для графика," << tablePoints.size() << "для таблицы";
    }
    else {
        sendResponse(client, "ERROR|Unknown command");
    }
}

void PostgreSQLServer::sendResponse(QTcpSocket* client, const QString& response)
{
    client->write(response.toUtf8());
    client->write("\n");
}
EOF

echo "   ✅ postgresqlserver.cpp обновлен"

# ============================================================================
# 3. ОБНОВЛЕНИЕ .env ФАЙЛА
# ============================================================================
echo ""
echo "3. Обновление .env файла..."

cat > .env << 'EOF'
# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=plotter_user
POSTGRES_PASSWORD=plotter123
POSTGRES_DB=function_plotter

# SMTP - ЗАМЕНИТЕ НА СВОИ ДАННЫЕ!
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=krasnovav932@gmail.com
SMTP_PASSWORD=nwtpimugzozbedrp
FROM_EMAIL=krasnovav932@gmail.com
EOF

echo "   ✅ .env создан"
echo "   ⚠️ Проверьте и при необходимости отредактируйте .env"

# ============================================================================
# 4. ПРОВЕРКА .gitignore
# ============================================================================
echo ""
echo "4. Обновление .gitignore..."

if ! grep -q ".env" .gitignore; then
    echo ".env" >> .gitignore
    echo "server/email_config.h" >> .gitignore
fi

echo "   ✅ .gitignore обновлен"

# ============================================================================
# 5. ПЕРЕСБОРКА И ЗАПУСК
# ============================================================================
echo ""
echo "5. Пересборка и запуск..."

cd server
make clean 2>/dev/null
qmake server.pro 2>/dev/null
make -j$(nproc) 2>/dev/null

cd ..
docker-compose down 2>/dev/null
docker-compose build --no-cache server 2>/dev/null
docker-compose up -d 2>/dev/null

echo "   ✅ Сервер пересобран и запущен"

# ============================================================================
# 6. ПРОВЕРКА ПЕРЕМЕННЫХ ОКРУЖЕНИЯ
# ============================================================================
echo ""
echo "6. Проверка переменных окружения в контейнере..."

sleep 3
docker exec function_plotter_server env | grep SMTP || echo "   ⚠️ Переменные SMTP не найдены"

# ============================================================================
# 7. ИТОГ
# ============================================================================
echo ""
echo "=========================================="
echo "  ГОТОВО!"
echo "=========================================="
echo ""
echo "✅ Что сделано:"
echo "   - Обновлен Python скрипт для отправки email"
echo "   - Обновлена функция sendEmail в сервере"
echo "   - Создан .env файл с настройками SMTP"
echo "   - Сервер пересобран и запущен"
echo ""
echo "📧 Проверьте .env файл и укажите свои SMTP данные:"
echo "   nano ~/projects/function-plotter-copy/timp-project/.env"
echo ""
echo "🚀 Проверить логи:"
echo "   docker-compose logs -f server"
echo ""
echo "🔑 Код для теста выводится в консоль сервера"
echo "=========================================="
EOF

chmod +x fix_email.sh
./fix_email.sh
