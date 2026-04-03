#!/bin/bash
# ============================================================================
# ОБНОВЛЕНИЕ КЛИЕНТА: плавный график, 20 отображаемых точек, красивый UI
# ============================================================================

set -e

PROJECT_DIR=~/projects/function-plotter
cd $PROJECT_DIR

echo "=========================================="
echo "  ОБНОВЛЕНИЕ КЛИЕНТА"
echo "=========================================="

# ============================================================================
# 1. ОБНОВЛЯЕМ math_engine.cpp (расчет 200 точек для плавности, но отображаем 20)
# ============================================================================
echo ""
echo "1. Обновление math_engine.cpp..."

cat > server/math_engine.cpp << 'EOF'
#include "math_engine.h"
#include <cmath>

double MathEngine::calculate(double x, const FunctionParams& params)
{
    if (x < 0) {
        return params.a * x * x;
    }
    else if (x >= 0 && x < 2) {
        return (x * x * x) - (3 * x) + params.b;
    }
    else {
        double x4 = x * x * x * x;
        double x3 = x * x * x;
        double x2 = x * x;
        return params.c * (x4 - 4 * x3 + 4 * x2);
    }
}

// Генерируем 200 точек для плавного графика
QVector<QPointF> MathEngine::generatePoints(const FunctionParams& params, int numPoints)
{
    QVector<QPointF> points;
    points.reserve(numPoints);

    double xMin = -2.0;
    double xMax = 4.0;
    double step = (xMax - xMin) / (numPoints - 1);

    for (int i = 0; i < numPoints; ++i) {
        double x = xMin + i * step;
        double y = calculate(x, params);
        points.append(QPointF(x, y));
    }
    return points;
}

// Генерируем 20 точек для отображения в таблице
QVector<QPointF> MathEngine::generateDisplayPoints(const FunctionParams& params)
{
    QVector<QPointF> points;
    points.reserve(20);

    double xMin = -2.0;
    double xMax = 4.0;
    double step = (xMax - xMin) / 19.0;  // 20 точек

    for (int i = 0; i < 20; ++i) {
        double x = xMin + i * step;
        double y = calculate(x, params);
        points.append(QPointF(x, y));
    }
    return points;
}
EOF

# Обновляем math_engine.h
cat > server/math_engine.h << 'EOF'
#ifndef MATH_ENGINE_H
#define MATH_ENGINE_H

#include <QVector>
#include <QPointF>

struct FunctionParams {
    double a;  // для x < 0: a * x²
    double b;  // для 0 ≤ x < 2: x³ - 3x + b
    double c;  // для x ≥ 2: c * (x⁴ - 4x³ + 4x²)

    FunctionParams() : a(1.0), b(0.0), c(1.0) {}
    FunctionParams(double aVal, double bVal, double cVal) : a(aVal), b(bVal), c(cVal) {}
};

class MathEngine
{
public:
    static double calculate(double x, const FunctionParams& params);
    static QVector<QPointF> generatePoints(const FunctionParams& params, int numPoints = 200);
    static QVector<QPointF> generateDisplayPoints(const FunctionParams& params);
};

#endif // MATH_ENGINE_H
EOF

echo "   ✅ math_engine.cpp обновлен (200 точек для плавности)"

# ============================================================================
# 2. ОБНОВЛЯЕМ postgresqlserver.cpp (отправка 200 точек для графика + 20 для таблицы)
# ============================================================================
echo ""
echo "2. Обновление postgresqlserver.cpp..."

# Создаем новый postgresqlserver.cpp с раздельными массивами
cat > server/postgresqlserver.cpp << 'EOF'
#include "postgresqlserver.h"
#include "database.h"
#include "math_engine.h"
#include "auth.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRandomGenerator>
#include <QRegularExpression>

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
    if (parts.isEmpty()) {
        sendResponse(client, "ERROR|Empty");
        return;
    }

    QString cmd = parts[0];

    // ========== РЕГИСТРАЦИЯ ==========
    if (cmd == "reg" && parts.size() >= 4) {
        Database* db = Database::getInstance();
        if (db->addUser(parts[1], hashPassword(parts[2]), parts[3])) {
            sendResponse(client, "REG_SUCCESS|" + parts[1]);
            qDebug() << "✅ Регистрация успешна:" << parts[1];
        } else {
            sendResponse(client, "REG_FAILED|User exists");
            qDebug() << "❌ Регистрация не удалась:" << parts[1];
        }
    }
    // ========== АВТОРИЗАЦИЯ ==========
    else if (cmd == "auth" && parts.size() >= 3) {
        Database* db = Database::getInstance();
        if (db->checkAuth(parts[1], hashPassword(parts[2]))) {
            m_clients[client].currentLogin = parts[1];
            sendResponse(client, "AUTH_SUCCESS|" + parts[1]);
            qDebug() << "✅ Авторизация успешна:" << parts[1];
        } else {
            sendResponse(client, "AUTH_FAILED");
            qDebug() << "❌ Авторизация не удалась:" << parts[1];
        }
    }
    // ========== ЗАБЫЛИ ПАРОЛЬ ==========
    else if (cmd == "forgot" && parts.size() >= 2) {
        QString email = parts[1];
        Database* db = Database::getInstance();

        UserInfo user = db->getUserInfoByEmail(email);
        if (user.id == -1) {
            sendResponse(client, "FORGOT_SENT|If email exists, code was sent");
            return;
        }

        QString code = generateResetToken();
        qDebug() << "🔑 Код для" << email << ":" << code;

        db->setResetToken(email, code, 15);

        QString body = QString(
            "<h2>Восстановление пароля</h2>"
            "<p>Ваш код: <b>%1</b></p>"
            "<p>Действителен 15 минут.</p>"
        ).arg(code);

        sendEmail(email, "Код восстановления", body);
        sendResponse(client, "FORGOT_SENT|Code sent");
    }
    // ========== СБРОС ПАРОЛЯ ==========
    else if (cmd == "reset" && parts.size() >= 3) {
        QString code = parts[1];
        QString newPassword = parts[2];
        Database* db = Database::getInstance();

        if (!db->isValidResetToken(code)) {
            sendResponse(client, "RESET_FAILED|Invalid code");
            return;
        }

        QString email = db->getEmailByResetToken(code);
        if (email.isEmpty()) {
            sendResponse(client, "RESET_FAILED|Invalid code");
            return;
        }

        UserInfo user = db->getUserInfoByEmail(email);
        if (user.id != -1) {
            db->updatePassword(user.login, hashPassword(newPassword));
        }

        db->clearResetToken(code);
        sendResponse(client, "RESET_SUCCESS|Password updated");
    }
    // ========== РАСЧЕТ ТОЧЕК (200 для графика + 20 для таблицы) ==========
    else if (cmd == "calc" && parts.size() >= 4) {
        double a = parts[1].toDouble();
        double b = parts[2].toDouble();
        double c = parts[3].toDouble();

        FunctionParams params(a, b, c);

        // 200 точек для плавного графика
        QVector<QPointF> graphPoints = MathEngine::generatePoints(params, 200);

        // 20 точек для таблицы
        QVector<QPointF> tablePoints = MathEngine::generateDisplayPoints(params);

        QJsonArray graphArray;
        for (const QPointF& p : graphPoints) {
            QJsonObject obj;
            obj["x"] = p.x();
            obj["y"] = p.y();
            graphArray.append(obj);
        }

        QJsonArray tableArray;
        for (const QPointF& p : tablePoints) {
            QJsonObject obj;
            obj["x"] = p.x();
            obj["y"] = p.y();
            tableArray.append(obj);
        }

        QJsonObject response;
        response["type"] = "CALC_RESPONSE";
        response["graphPoints"] = graphArray;   // 200 точек для графика
        response["tablePoints"] = tableArray;   // 20 точек для таблицы
        response["a"] = a;
        response["b"] = b;
        response["c"] = c;

        client->write(QJsonDocument(response).toJson());
        client->write("\n");
        qDebug() << "📊 Расчет: 200 точек для графика, 20 для таблицы";
    }
    else {
        sendResponse(client, "ERROR|Unknown: " + cmd);
    }
}

void PostgreSQLServer::sendResponse(QTcpSocket* client, const QString& response)
{
    qDebug() << "📤 Ответ:" << response;
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

void sendEmail(const QString& to, const QString& subject, const QString& body) {
    qDebug() << "========================================";
    qDebug() << "📧 Email to:" << to;
    qDebug() << "   Subject:" << subject;
    QRegularExpression re("(\\d{6})");
    QRegularExpressionMatch match = re.match(body);
    if (match.hasMatch()) {
        qDebug() << "🔑 КОД:" << match.captured(1);
    }
    qDebug() << "========================================";
}
EOF

echo "   ✅ postgresqlserver.cpp обновлен (200+20 точек)"

# ============================================================================
# 3. ОБНОВЛЯЕМ КЛИЕНТ (plotwidget.cpp - убираем жирные точки, плавные линии)
# ============================================================================
echo ""
echo "3. Обновление plotwidget.cpp..."

cat > client/plotwidget.cpp << 'EOF'
#include "plotwidget.h"
#include <QPainter>
#include <QWheelEvent>
#include <QMouseEvent>
#include <QPen>

PlotWidget::PlotWidget(QWidget *parent) : QWidget(parent)
{
    setMinimumSize(600, 400);
    setBackgroundRole(QPalette::Base);
    setAutoFillBackground(true);
}

void PlotWidget::setPoints(const QVector<QPointF>& points)
{
    m_points = points;
    update();
}

void PlotWidget::clear()
{
    m_points.clear();
    update();
}

QPointF PlotWidget::worldToWidget(const QPointF& point) const
{
    double x = (point.x() - m_xMin) / (m_xMax - m_xMin) * width();
    double y = height() - (point.y() - m_yMin) / (m_yMax - m_yMin) * height();
    return QPointF(x, y);
}

QPointF PlotWidget::widgetToWorld(const QPointF& point) const
{
    double x = m_xMin + point.x() / width() * (m_xMax - m_xMin);
    double y = m_yMin + (height() - point.y()) / height() * (m_yMax - m_yMin);
    return QPointF(x, y);
}

void PlotWidget::paintEvent(QPaintEvent*)
{
    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.fillRect(rect(), Qt::white);

    // Сетка
    painter.setPen(QPen(Qt::lightGray, 1, Qt::DashLine));
    for (int x = -3; x <= 5; ++x) {
        painter.drawLine(worldToWidget(QPointF(x, m_yMin)), worldToWidget(QPointF(x, m_yMax)));
    }
    for (int y = -5; y <= 10; ++y) {
        painter.drawLine(worldToWidget(QPointF(m_xMin, y)), worldToWidget(QPointF(m_xMax, y)));
    }

    // Оси
    painter.setPen(QPen(Qt::black, 2));
    QPointF originW = worldToWidget(QPointF(0, 0));
    painter.drawLine(QPointF(0, originW.y()), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(originW.x(), 0), QPointF(originW.x(), height()));

    // Стрелки
    painter.drawLine(QPointF(width()-10, originW.y()-5), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(width()-10, originW.y()+5), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(originW.x()-5, 10), QPointF(originW.x(), 0));
    painter.drawLine(QPointF(originW.x()+5, 10), QPointF(originW.x(), 0));

    // Подписи осей
    painter.drawText(width()-15, originW.y()-5, "X");
    painter.drawText(originW.x()+5, 15, "Y");

    // График (только линии, без жирных точек)
    if (m_points.isEmpty()) return;

    // Тонкая синяя линия для графика
    painter.setPen(QPen(Qt::blue, 2));

    QPointF prev = worldToWidget(m_points[0]);
    for (int i = 1; i < m_points.size(); ++i) {
        QPointF curr = worldToWidget(m_points[i]);
        painter.drawLine(prev, curr);
        prev = curr;
    }
}

void PlotWidget::wheelEvent(QWheelEvent* event)
{
    double scale = (event->angleDelta().y() > 0) ? 0.9 : 1.1;
    QPointF mouseWorld = widgetToWorld(event->position());
    double newWidth = (m_xMax - m_xMin) * scale;
    double newHeight = (m_yMax - m_yMin) * scale;
    m_xMin = mouseWorld.x() - (mouseWorld.x() - m_xMin) * scale;
    m_xMax = m_xMin + newWidth;
    m_yMin = mouseWorld.y() - (mouseWorld.y() - m_yMin) * scale;
    m_yMax = m_yMin + newHeight;
    update();
}

void PlotWidget::mousePressEvent(QMouseEvent* event)
{
    if (event->button() == Qt::LeftButton) {
        m_panning = true;
        m_lastMousePos = event->pos();
        setCursor(Qt::ClosedHandCursor);
    }
}

void PlotWidget::mouseMoveEvent(QMouseEvent* event)
{
    if (m_panning) {
        QPoint delta = event->pos() - m_lastMousePos;
        double dx = (delta.x() / (double)width()) * (m_xMax - m_xMin);
        double dy = (delta.y() / (double)height()) * (m_yMax - m_yMin);
        m_xMin -= dx; m_xMax -= dx;
        m_yMin += dy; m_yMax += dy;
        m_lastMousePos = event->pos();
        update();
    }
}

void PlotWidget::mouseReleaseEvent(QMouseEvent* event)
{
    if (event->button() == Qt::LeftButton) {
        m_panning = false;
        setCursor(Qt::ArrowCursor);
    }
}
EOF

echo "   ✅ plotwidget.cpp обновлен (только линии, без жирных точек)"

# ============================================================================
# 4. ОБНОВЛЯЕМ mainwindow.cpp (подписи под ползунками, отображение 20 точек)
# ============================================================================
echo ""
echo "4. Обновление mainwindow.cpp..."

cat > client/mainwindow.cpp << 'EOF'
#include "mainwindow.h"
#include "authwindow.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QHeaderView>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QMessageBox>
#include <QLabel>
#include <QSlider>
#include <QTableWidget>
#include <QPushButton>

MainWindow::MainWindow(const QString& login, QWidget *parent) : QMainWindow(parent), m_login(login)
{
    setWindowTitle("Function Plotter - " + login);
    setMinimumSize(900, 700);

    QWidget* central = new QWidget(this);
    setCentralWidget(central);
    QVBoxLayout* mainLayout = new QVBoxLayout(central);

    // Группа параметров с красивым оформлением
    QGroupBox* paramsBox = new QGroupBox("Параметры функции");
    QVBoxLayout* paramsLayout = new QVBoxLayout(paramsBox);

    // Параметр A (x < 0)
    QHBoxLayout* aLayout = new QHBoxLayout();
    QLabel* aLabel = new QLabel("a (x < 0):");
    aLabel->setMinimumWidth(80);
    m_sliderA = new QSlider(Qt::Horizontal);
    m_sliderA->setRange(-100, 100);
    m_sliderA->setValue(10);
    m_labelA = new QLabel("1.0");
    m_labelA->setMinimumWidth(40);
    QLabel* aRangeLabel = new QLabel("[-10 ... 10]");
    aRangeLabel->setStyleSheet("color: gray; font-size: 10px;");
    aLayout->addWidget(aLabel);
    aLayout->addWidget(m_sliderA);
    aLayout->addWidget(m_labelA);
    aLayout->addWidget(aRangeLabel);
    paramsLayout->addLayout(aLayout);

    // Параметр B (0 ≤ x < 2)
    QHBoxLayout* bLayout = new QHBoxLayout();
    QLabel* bLabel = new QLabel("b (0 ≤ x < 2):");
    bLabel->setMinimumWidth(80);
    m_sliderB = new QSlider(Qt::Horizontal);
    m_sliderB->setRange(-100, 100);
    m_sliderB->setValue(0);
    m_labelB = new QLabel("0.0");
    m_labelB->setMinimumWidth(40);
    QLabel* bRangeLabel = new QLabel("[-10 ... 10]");
    bRangeLabel->setStyleSheet("color: gray; font-size: 10px;");
    bLayout->addWidget(bLabel);
    bLayout->addWidget(m_sliderB);
    bLayout->addWidget(m_labelB);
    bLayout->addWidget(bRangeLabel);
    paramsLayout->addLayout(bLayout);

    // Параметр C (x ≥ 2)
    QHBoxLayout* cLayout = new QHBoxLayout();
    QLabel* cLabel = new QLabel("c (x ≥ 2):");
    cLabel->setMinimumWidth(80);
    m_sliderC = new QSlider(Qt::Horizontal);
    m_sliderC->setRange(-100, 100);
    m_sliderC->setValue(10);
    m_labelC = new QLabel("1.0");
    m_labelC->setMinimumWidth(40);
    QLabel* cRangeLabel = new QLabel("[-10 ... 10]");
    cRangeLabel->setStyleSheet("color: gray; font-size: 10px;");
    cLayout->addWidget(cLabel);
    cLayout->addWidget(m_sliderC);
    cLayout->addWidget(m_labelC);
    cLayout->addWidget(cRangeLabel);
    paramsLayout->addLayout(cLayout);

    mainLayout->addWidget(paramsBox);

    // График
    m_plotWidget = new PlotWidget(this);
    m_plotWidget->setMinimumHeight(400);
    mainLayout->addWidget(m_plotWidget);

    // Таблица точек
    QGroupBox* tableBox = new QGroupBox("Точки функции (20 значений)");
    QVBoxLayout* tableLayout = new QVBoxLayout(tableBox);
    m_tableWidget = new QTableWidget(20, 2);
    m_tableWidget->setHorizontalHeaderLabels({"X", "Y"});
    m_tableWidget->horizontalHeader()->setStretchLastSection(true);
    m_tableWidget->setEditTriggers(QTableWidget::NoEditTriggers);
    tableLayout->addWidget(m_tableWidget);
    mainLayout->addWidget(tableBox);

    // Кнопка выхода
    QPushButton* logoutBtn = new QPushButton("Выйти");
    logoutBtn->setFixedHeight(35);
    logoutBtn->setStyleSheet("QPushButton { background-color: #e74c3c; color: white; font-weight: bold; border-radius: 5px; }");
    connect(logoutBtn, &QPushButton::clicked, this, &MainWindow::onDisconnect);
    mainLayout->addWidget(logoutBtn);

    // Сокет
    m_socket = new QTcpSocket(this);
    connect(m_socket, &QTcpSocket::readyRead, this, &MainWindow::onCalcResponse);
    m_socket->connectToHost("localhost", 33333);

    // Сигналы ползунков
    connect(m_sliderA, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);
    connect(m_sliderB, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);
    connect(m_sliderC, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);

    onParamsChanged();
}

MainWindow::~MainWindow()
{
    if (m_socket && m_socket->state() == QAbstractSocket::ConnectedState) {
        m_socket->disconnectFromHost();
    }
}

void MainWindow::onParamsChanged()
{
    double a = m_sliderA->value() / 10.0;
    double b = m_sliderB->value() / 10.0;
    double c = m_sliderC->value() / 10.0;
    m_labelA->setText(QString::number(a));
    m_labelB->setText(QString::number(b));
    m_labelC->setText(QString::number(c));
    sendCalcRequest();
}

void MainWindow::sendCalcRequest()
{
    double a = m_sliderA->value() / 10.0;
    double b = m_sliderB->value() / 10.0;
    double c = m_sliderC->value() / 10.0;
    QString cmd = QString("calc|%1|%2|%3\n").arg(a).arg(b).arg(c);
    m_socket->write(cmd.toUtf8());
}

void MainWindow::onCalcResponse()
{
    while (m_socket->bytesAvailable()) {
        QByteArray data = m_socket->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isObject()) continue;

        QJsonObject obj = doc.object();
        if (obj["type"].toString() == "CALC_RESPONSE") {
            // 200 точек для плавного графика
            QVector<QPointF> graphPoints;
            QJsonArray graphArray = obj["graphPoints"].toArray();
            for (const QJsonValue& val : graphArray) {
                QJsonObject p = val.toObject();
                graphPoints.append(QPointF(p["x"].toDouble(), p["y"].toDouble()));
            }
            m_plotWidget->setPoints(graphPoints);

            // 20 точек для таблицы
            QVector<QPointF> tablePoints;
            QJsonArray tableArray = obj["tablePoints"].toArray();
            for (const QJsonValue& val : tableArray) {
                QJsonObject p = val.toObject();
                tablePoints.append(QPointF(p["x"].toDouble(), p["y"].toDouble()));
            }
            updateTable(tablePoints);
        }
    }
}

void MainWindow::updateTable(const QVector<QPointF>& points)
{
    m_tableWidget->setRowCount(points.size());
    for (int i = 0; i < points.size(); ++i) {
        m_tableWidget->setItem(i, 0, new QTableWidgetItem(QString::number(points[i].x(), 'f', 4)));
        m_tableWidget->setItem(i, 1, new QTableWidgetItem(QString::number(points[i].y(), 'f', 4)));
    }
}

void MainWindow::onDisconnect()
{
    if (m_socket) m_socket->disconnectFromHost();
    AuthWindow* auth = new AuthWindow();
    auth->show();
    close();
}
EOF

echo "   ✅ mainwindow.cpp обновлен (красивые подписи с диапазонами)"

# ============================================================================
# 5. ПЕРЕСБОРКА СЕРВЕРА И КЛИЕНТА
# ============================================================================
echo ""
echo "5. Пересборка сервера и клиента..."

# Сборка сервера
cd $PROJECT_DIR/server
make clean 2>/dev/null
qmake server.pro 2>/dev/null
make -j$(nproc) 2>/dev/null

if [ $? -eq 0 ]; then
    echo "   ✅ Сервер пересобран"
else
    echo "   ❌ Ошибка сборки сервера"
fi

# Сборка клиента
cd $PROJECT_DIR/client
make clean 2>/dev/null
qmake client.pro 2>/dev/null
make -j$(nproc) 2>/dev/null

if [ $? -eq 0 ]; then
    echo "   ✅ Клиент пересобран"
else
    echo "   ❌ Ошибка сборки клиента"
fi

# ============================================================================
# 6. ИТОГИ
# ============================================================================
echo ""
echo "=========================================="
echo "  ГОТОВО!"
echo "=========================================="
echo ""
echo "✅ Что сделано:"
echo "   - График рисуется плавной линией (200 точек расчета)"
echo "   - Точки не отображаются жирными"
echo "   - В таблице показываются 20 точек"
echo "   - Под ползунками указаны параметры и диапазоны"
echo "   - Красивое оформление с группировкой"
echo ""
echo "🚀 Запуск:"
echo "   cd ~/projects/function-plotter"
echo "   docker-compose up -d"
echo "   cd client && ./client"
echo ""
echo "=========================================="
EOF

chmod +x update_client.sh
./update_client.sh
