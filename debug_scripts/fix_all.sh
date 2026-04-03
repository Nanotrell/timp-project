#!/bin/bash
# ============================================================================
# ПОЛНОЕ ИСПРАВЛЕНИЕ: график, таблица, ползунки, оси
# ============================================================================

set -e

PROJECT_DIR=~/projects/function-plotter
cd $PROJECT_DIR

echo "=========================================="
echo "  ИСПРАВЛЕНИЕ ВСЕХ ПРОБЛЕМ"
echo "=========================================="

# ============================================================================
# 1. ИСПРАВЛЯЕМ math_engine.h
# ============================================================================
echo ""
echo "1. Исправление math_engine.h..."

cat > server/math_engine.h << 'EOF'
#ifndef MATH_ENGINE_H
#define MATH_ENGINE_H

#include <QVector>
#include <QPointF>

struct FunctionParams {
    double a;
    double b;
    double c;

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

# ============================================================================
# 2. ИСПРАВЛЯЕМ math_engine.cpp
# ============================================================================
echo ""
echo "2. Исправление math_engine.cpp..."

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

QVector<QPointF> MathEngine::generatePoints(const FunctionParams& params, int numPoints)
{
    QVector<QPointF> points;
    points.reserve(numPoints);

    double xMin = -3.0;
    double xMax = 5.0;
    double step = (xMax - xMin) / (numPoints - 1);

    for (int i = 0; i < numPoints; ++i) {
        double x = xMin + i * step;
        double y = calculate(x, params);
        points.append(QPointF(x, y));
    }
    return points;
}

QVector<QPointF> MathEngine::generateDisplayPoints(const FunctionParams& params)
{
    QVector<QPointF> points;
    points.reserve(20);

    double xMin = -3.0;
    double xMax = 5.0;
    double step = (xMax - xMin) / 19.0;

    for (int i = 0; i < 20; ++i) {
        double x = xMin + i * step;
        double y = calculate(x, params);
        points.append(QPointF(x, y));
    }
    return points;
}
EOF

# ============================================================================
# 3. ИСПРАВЛЯЕМ postgresqlserver.cpp (отправка точек)
# ============================================================================
echo ""
echo "3. Исправление postgresqlserver.cpp..."

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

        QString body = QString("<h2>Восстановление пароля</h2><p>Ваш код: <b>%1</b></p>").arg(code);
        sendEmail(email, "Код восстановления", body);
        sendResponse(client, "FORGOT_SENT|Code sent");
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
    else if (cmd == "calc" && parts.size() >= 4) {
        double a = parts[1].toDouble();
        double b = parts[2].toDouble();
        double c = parts[3].toDouble();

        FunctionParams params(a, b, c);

        // 200 точек для плавного графика
        QVector<QPointF> graphPoints = MathEngine::generatePoints(params, 200);
        QJsonArray graphArray;
        for (const QPointF& p : graphPoints) {
            QJsonObject obj;
            obj["x"] = p.x();
            obj["y"] = p.y();
            graphArray.append(obj);
        }

        // 20 точек для таблицы
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
    QRegularExpression re("(\\d{6})");
    QRegularExpressionMatch match = re.match(body);
    if (match.hasMatch()) {
        qDebug() << "🔑 КОД:" << match.captured(1);
    }
    qDebug() << "========================================";
}
EOF

# ============================================================================
# 4. ИСПРАВЛЯЕМ plotwidget.cpp (фиксированный размер, центр, равные оси)
# ============================================================================
echo ""
echo "4. Исправление plotwidget.cpp..."

cat > client/plotwidget.cpp << 'EOF'
#include "plotwidget.h"
#include <QPainter>
#include <QWheelEvent>
#include <QMouseEvent>
#include <QResizeEvent>

PlotWidget::PlotWidget(QWidget *parent) : QWidget(parent)
{
    setMinimumSize(600, 600);
    setMaximumSize(600, 600);
    setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);
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

    // Оси (проходят через 0)
    painter.setPen(QPen(Qt::black, 2));
    QPointF originW = worldToWidget(QPointF(0, 0));

    // Ось X
    painter.drawLine(QPointF(0, originW.y()), QPointF(width(), originW.y()));
    // Ось Y
    painter.drawLine(QPointF(originW.x(), 0), QPointF(originW.x(), height()));

    // Стрелки
    painter.drawLine(QPointF(width()-10, originW.y()-5), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(width()-10, originW.y()+5), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(originW.x()-5, 10), QPointF(originW.x(), 0));
    painter.drawLine(QPointF(originW.x()+5, 10), QPointF(originW.x(), 0));

    // Подписи
    painter.drawText(width()-15, originW.y()-5, "X");
    painter.drawText(originW.x()+5, 15, "Y");

    // График
    if (m_points.isEmpty()) return;

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

# ============================================================================
# 5. ИСПРАВЛЯЕМ mainwindow.cpp (нормальные ползунки)
# ============================================================================
echo ""
echo "5. Исправление mainwindow.cpp..."

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
    setFixedSize(900, 750);

    QWidget* central = new QWidget(this);
    setCentralWidget(central);
    QVBoxLayout* mainLayout = new QVBoxLayout(central);

    // ========== ПАРАМЕТРЫ ==========
    QGroupBox* paramsBox = new QGroupBox("Параметры функции");
    QVBoxLayout* paramsLayout = new QVBoxLayout(paramsBox);

    // a
    QHBoxLayout* aLayout = new QHBoxLayout();
    QLabel* aLabel = new QLabel("a (x < 0):");
    aLabel->setMinimumWidth(100);
    m_sliderA = new QSlider(Qt::Horizontal);
    m_sliderA->setRange(-100, 100);
    m_sliderA->setValue(10);
    m_labelA = new QLabel("1.0");
    m_labelA->setMinimumWidth(40);
    QLabel* aRange = new QLabel("[-10 ... 10]");
    aRange->setStyleSheet("color: #888; font-size: 10px;");
    aLayout->addWidget(aLabel);
    aLayout->addWidget(m_sliderA);
    aLayout->addWidget(m_labelA);
    aLayout->addWidget(aRange);
    paramsLayout->addLayout(aLayout);

    // b
    QHBoxLayout* bLayout = new QHBoxLayout();
    QLabel* bLabel = new QLabel("b (0 ≤ x < 2):");
    bLabel->setMinimumWidth(100);
    m_sliderB = new QSlider(Qt::Horizontal);
    m_sliderB->setRange(-100, 100);
    m_sliderB->setValue(0);
    m_labelB = new QLabel("0.0");
    m_labelB->setMinimumWidth(40);
    QLabel* bRange = new QLabel("[-10 ... 10]");
    bRange->setStyleSheet("color: #888; font-size: 10px;");
    bLayout->addWidget(bLabel);
    bLayout->addWidget(m_sliderB);
    bLayout->addWidget(m_labelB);
    bLayout->addWidget(bRange);
    paramsLayout->addLayout(bLayout);

    // c
    QHBoxLayout* cLayout = new QHBoxLayout();
    QLabel* cLabel = new QLabel("c (x ≥ 2):");
    cLabel->setMinimumWidth(100);
    m_sliderC = new QSlider(Qt::Horizontal);
    m_sliderC->setRange(-100, 100);
    m_sliderC->setValue(10);
    m_labelC = new QLabel("1.0");
    m_labelC->setMinimumWidth(40);
    QLabel* cRange = new QLabel("[-10 ... 10]");
    cRange->setStyleSheet("color: #888; font-size: 10px;");
    cLayout->addWidget(cLabel);
    cLayout->addWidget(m_sliderC);
    cLayout->addWidget(m_labelC);
    cLayout->addWidget(cRange);
    paramsLayout->addLayout(cLayout);

    mainLayout->addWidget(paramsBox);

    // ========== ГРАФИК ==========
    m_plotWidget = new PlotWidget(this);
    mainLayout->addWidget(m_plotWidget);

    // ========== ТАБЛИЦА ==========
    QGroupBox* tableBox = new QGroupBox("Точки функции (20 значений)");
    QVBoxLayout* tableLayout = new QVBoxLayout(tableBox);
    m_tableWidget = new QTableWidget(20, 2);
    m_tableWidget->setHorizontalHeaderLabels({"X", "Y"});
    m_tableWidget->horizontalHeader()->setStretchLastSection(true);
    m_tableWidget->setEditTriggers(QTableWidget::NoEditTriggers);
    tableLayout->addWidget(m_tableWidget);
    mainLayout->addWidget(tableBox);

    // ========== КНОПКА ВЫХОДА ==========
    QPushButton* logoutBtn = new QPushButton("Выйти");
    logoutBtn->setFixedHeight(35);
    logoutBtn->setStyleSheet("QPushButton { background-color: #e74c3c; color: white; font-weight: bold; border-radius: 5px; }");
    connect(logoutBtn, &QPushButton::clicked, this, &MainWindow::onDisconnect);
    mainLayout->addWidget(logoutBtn);

    // ========== СОКЕТ ==========
    m_socket = new QTcpSocket(this);
    connect(m_socket, &QTcpSocket::readyRead, this, &MainWindow::onCalcResponse);
    m_socket->connectToHost("localhost", 33333);

    // ========== СИГНАЛЫ ПОЛЗУНКОВ ==========
    connect(m_sliderA, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);
    connect(m_sliderB, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);
    connect(m_sliderC, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);

    // Первый расчет
    QTimer::singleShot(500, this, &MainWindow::onParamsChanged);
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
    qDebug() << "Отправлен запрос:" << cmd.trimmed();
}

void MainWindow::onCalcResponse()
{
    while (m_socket->bytesAvailable()) {
        QByteArray data = m_socket->readAll();
        qDebug() << "Получены данные:" << data.left(100);

        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isObject()) {
            qDebug() << "Не JSON объект";
            continue;
        }

        QJsonObject obj = doc.object();
        if (obj["type"].toString() == "CALC_RESPONSE") {
            // 200 точек для графика
            QVector<QPointF> graphPoints;
            QJsonArray graphArray = obj["graphPoints"].toArray();
            for (const QJsonValue& val : graphArray) {
                QJsonObject p = val.toObject();
                graphPoints.append(QPointF(p["x"].toDouble(), p["y"].toDouble()));
            }
            m_plotWidget->setPoints(graphPoints);
            qDebug() << "График обновлен:" << graphPoints.size() << "точек";

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

# ============================================================================
# 6. ДОБАВЛЯЕМ QTimer В mainwindow.h
# ============================================================================
echo ""
echo "6. Исправление mainwindow.h..."

cat > client/mainwindow.h << 'EOF'
#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QTcpSocket>
#include <QSlider>
#include <QLabel>
#include <QTableWidget>
#include <QTimer>
#include "plotwidget.h"

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(const QString& login, QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void onParamsChanged();
    void onCalcResponse();
    void onDisconnect();

private:
    void sendCalcRequest();
    void updateTable(const QVector<QPointF>& points);

    QTcpSocket* m_socket;
    PlotWidget* m_plotWidget;
    QTableWidget* m_tableWidget;
    QSlider* m_sliderA;
    QSlider* m_sliderB;
    QSlider* m_sliderC;
    QLabel* m_labelA;
    QLabel* m_labelB;
    QLabel* m_labelC;
    QString m_login;
};

#endif // MAINWINDOW_H
EOF

# ============================================================================
# 7. ПЕРЕСБОРКА
# ============================================================================
echo ""
echo "7. Пересборка сервера и клиента..."

cd $PROJECT_DIR/server
make clean 2>/dev/null
qmake server.pro 2>/dev/null
make -j$(nproc) 2>/dev/null

if [ $? -eq 0 ]; then
    echo "   ✅ Сервер пересобран"
else
    echo "   ❌ Ошибка сборки сервера"
fi

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
# 8. ЗАПУСК
# ============================================================================
echo ""
echo "=========================================="
echo "  ГОТОВО!"
echo "=========================================="
echo ""
echo "🚀 ЗАПУСК:"
echo ""
echo "  Терминал 1 (сервер):"
echo "    cd ~/projects/function-plotter/server"
echo "    ./server"
echo ""
echo "  Терминал 2 (клиент):"
echo "    cd ~/projects/function-plotter/client"
echo "    ./client"
echo ""
echo "✅ Что исправлено:"
echo "   - График рисуется плавной линией"
echo "   - Таблица заполняется 20 точками"
echo "   - Оси проходят через центр (0,0)"
echo "   - Окно графика фиксированного размера 600x600"
echo "   - Ползунки работают корректно"
echo ""
echo "=========================================="
EOF

