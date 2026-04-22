#include "postgresqlserver.h"
#include "database.h"
#include "math_engine.h"
#include "auth.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTcpSocket>
#include <QRegularExpression>

// ========== ОТПРАВКА EMAIL (упрощённая) ==========
void sendEmail(const QString& to, const QString& subject, const QString& body)
{
    Q_UNUSED(subject);
    qDebug() << "========================================";
    qDebug() << "📧 Email to:" << to;
    
    QRegularExpression re("(\\d{6})");
    QRegularExpressionMatch match = re.match(body);
    QString code = match.hasMatch() ? match.captured(1) : "???";
    qDebug() << "🔑 Код:" << code;
    qDebug() << "========================================";
}

// ========== КОНСТРУКТОР И ДЕСТРУКТОР ==========
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
    
    int numPoints = 200;  // значение по умолчанию
    if (parts.size() >= 5) {
        numPoints = parts[4].toInt();
        // Ограничения
        if (numPoints < 10) numPoints = 10;
        if (numPoints > 1000) numPoints = 1000;
    }
    
    FunctionParams params(a, b, c);
    
    // numPoints точек для плавного графика (шаг = (xMax - xMin) / (numPoints - 1))
    QVector<QPointF> graphPoints = MathEngine::generatePoints(params, numPoints);
    QJsonArray graphArray;
    for (const QPointF& p : graphPoints) {
        QJsonObject obj;
        obj["x"] = p.x();
        obj["y"] = p.y();
        graphArray.append(obj);
    }
    
    // 20 точек для таблицы (всегда 20)
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
    response["numPoints"] = numPoints;
    
    client->write(QJsonDocument(response).toJson());
    client->write("\n");
    qDebug() << "📊 Отправлено:" << graphPoints.size() << "точек для графика (шаг:" 
             << (40.0 / (numPoints - 1)) << ")," << tablePoints.size() << "для таблицы";
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
