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
#include <QResizeEvent>
#include <QTimer>

MainWindow::MainWindow(const QString& login, QWidget *parent) : QMainWindow(parent), m_login(login)
{
    setWindowTitle("Function Plotter - " + login);
    setMinimumSize(800, 700);
    resize(1000, 750);
    
    QWidget* central = new QWidget(this);
    setCentralWidget(central);
    QVBoxLayout* mainLayout = new QVBoxLayout(central);
    mainLayout->setSpacing(10);
    
    // ========== ПАРАМЕТРЫ ==========
    QGroupBox* paramsBox = new QGroupBox("Параметры функции");
    QVBoxLayout* paramsLayout = new QVBoxLayout(paramsBox);
    paramsLayout->setSpacing(8);
    
    // a
    QHBoxLayout* aLayout = new QHBoxLayout();
    QLabel* aLabel = new QLabel("a (x < 0):");
    aLabel->setFixedWidth(80);
    m_sliderA = new QSlider(Qt::Horizontal);
    m_sliderA->setRange(-100, 100);
    m_sliderA->setValue(10);
    m_sliderA->setFixedWidth(250);
    m_labelA = new QLabel("1.0");
    m_labelA->setFixedWidth(40);
    QLabel* aRange = new QLabel("[-10 ... 10]");
    aRange->setStyleSheet("color: #888; font-size: 9px;");
    aRange->setFixedWidth(70);
    aLayout->addWidget(aLabel);
    aLayout->addWidget(m_sliderA);
    aLayout->addWidget(m_labelA);
    aLayout->addWidget(aRange);
    aLayout->addStretch();
    paramsLayout->addLayout(aLayout);
    
    // b
    QHBoxLayout* bLayout = new QHBoxLayout();
    QLabel* bLabel = new QLabel("b (0 ≤ x < 2):");
    bLabel->setFixedWidth(80);
    m_sliderB = new QSlider(Qt::Horizontal);
    m_sliderB->setRange(-100, 100);
    m_sliderB->setValue(0);
    m_sliderB->setFixedWidth(250);
    m_labelB = new QLabel("0.0");
    m_labelB->setFixedWidth(40);
    QLabel* bRange = new QLabel("[-10 ... 10]");
    bRange->setStyleSheet("color: #888; font-size: 9px;");
    bRange->setFixedWidth(70);
    bLayout->addWidget(bLabel);
    bLayout->addWidget(m_sliderB);
    bLayout->addWidget(m_labelB);
    bLayout->addWidget(bRange);
    bLayout->addStretch();
    paramsLayout->addLayout(bLayout);
    
    // c
    QHBoxLayout* cLayout = new QHBoxLayout();
    QLabel* cLabel = new QLabel("c (x ≥ 2):");
    cLabel->setFixedWidth(80);
    m_sliderC = new QSlider(Qt::Horizontal);
    m_sliderC->setRange(-100, 100);
    m_sliderC->setValue(10);
    m_sliderC->setFixedWidth(250);
    m_labelC = new QLabel("1.0");
    m_labelC->setFixedWidth(40);
    QLabel* cRange = new QLabel("[-10 ... 10]");
    cRange->setStyleSheet("color: #888; font-size: 9px;");
    cRange->setFixedWidth(70);
    cLayout->addWidget(cLabel);
    cLayout->addWidget(m_sliderC);
    cLayout->addWidget(m_labelC);
    cLayout->addWidget(cRange);
    cLayout->addStretch();
    paramsLayout->addLayout(cLayout);
    
    mainLayout->addWidget(paramsBox);
    
    // ========== ГРАФИК ==========
    m_plotWidget = new PlotWidget(this);
    m_plotWidget->setMinimumHeight(450);
    m_plotWidget->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Expanding);
    mainLayout->addWidget(m_plotWidget, 1);
    
    // ========== ТАБЛИЦА ==========
    QGroupBox* tableBox = new QGroupBox("Точки функции (20 значений)");
    QVBoxLayout* tableLayout = new QVBoxLayout(tableBox);
    m_tableWidget = new QTableWidget(20, 2);
    m_tableWidget->setHorizontalHeaderLabels({"X", "Y"});
    m_tableWidget->horizontalHeader()->setStretchLastSection(true);
    m_tableWidget->setEditTriggers(QTableWidget::NoEditTriggers);
    m_tableWidget->setMaximumHeight(200);
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
    connect(m_socket, &QTcpSocket::connected, this, [this]() {
        qDebug() << "Подключено к серверу";
        onParamsChanged();  // ← запрос на построение графика сразу после подключения
    });
    m_socket->connectToHost("localhost", 33333);
    
    // ========== СИГНАЛЫ ПОЛЗУНКОВ ==========
    connect(m_sliderA, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);
    connect(m_sliderB, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);
    connect(m_sliderC, &QSlider::valueChanged, this, &MainWindow::onParamsChanged);
    
    // Запасной таймер на случай, если сокет не подключился быстро
    QTimer::singleShot(1500, this, [this]() {
        if (m_socket->state() == QAbstractSocket::ConnectedState) {
            onParamsChanged();
        }
    });
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
    m_plotWidget->setFunctionParams(a, b, c);
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
        QString dataStr = QString::fromUtf8(data);
        qDebug() << "Получено:" << dataStr.left(200);
        
        if (!dataStr.trimmed().startsWith("{")) {
            qDebug() << "Не JSON, пропускаем";
            continue;
        }
        
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isObject()) {
            qDebug() << "Не объект JSON";
            continue;
        }
        
        QJsonObject obj = doc.object();
        
        if (obj.contains("a")) {
            double a = obj["a"].toDouble();
            double b = obj["b"].toDouble();
            double c = obj["c"].toDouble();
            m_plotWidget->setFunctionParams(a, b, c);
        }
        
        if (obj.contains("graphPoints")) {
            QVector<QPointF> graphPoints;
            QJsonArray graphArray = obj["graphPoints"].toArray();
            for (const QJsonValue& val : graphArray) {
                QJsonObject p = val.toObject();
                graphPoints.append(QPointF(p["x"].toDouble(), p["y"].toDouble()));
            }
            m_plotWidget->setPoints(graphPoints);
            qDebug() << "График обновлен:" << graphPoints.size() << "точек";
        }
        else if (obj.contains("points")) {
            QVector<QPointF> graphPoints;
            QJsonArray graphArray = obj["points"].toArray();
            for (const QJsonValue& val : graphArray) {
                QJsonObject p = val.toObject();
                graphPoints.append(QPointF(p["x"].toDouble(), p["y"].toDouble()));
            }
            m_plotWidget->setPoints(graphPoints);
            qDebug() << "График обновлен (old format):" << graphPoints.size() << "точек";
        }
        
        if (obj.contains("tablePoints")) {
            QVector<QPointF> tablePoints;
            QJsonArray tableArray = obj["tablePoints"].toArray();
            for (const QJsonValue& val : tableArray) {
                QJsonObject p = val.toObject();
                tablePoints.append(QPointF(p["x"].toDouble(), p["y"].toDouble()));
            }
            updateTable(tablePoints);
            qDebug() << "Таблица обновлена:" << tablePoints.size() << "точек";
        }
        else if (obj.contains("points")) {
            QVector<QPointF> tablePoints;
            QJsonArray pointsArray = obj["points"].toArray();
            for (int i = 0; i < pointsArray.size() && tablePoints.size() < 20; i += 10) {
                QJsonObject p = pointsArray[i].toObject();
                tablePoints.append(QPointF(p["x"].toDouble(), p["y"].toDouble()));
            }
            updateTable(tablePoints);
            qDebug() << "Таблица обновлена из графика:" << tablePoints.size() << "точек";
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
