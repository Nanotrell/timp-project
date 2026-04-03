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
