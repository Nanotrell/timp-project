#include "resetpassworddialog.h"
#include <QVBoxLayout>
#include <QFormLayout>
#include <QMessageBox>

ResetPasswordDialog::ResetPasswordDialog(QWidget *parent) : QDialog(parent), m_socket(nullptr)
{
    setWindowTitle("Восстановление пароля");
    setFixedSize(400, 380);
    setModal(true);
    
    QVBoxLayout* mainLayout = new QVBoxLayout(this);
    
    QLabel* infoLabel = new QLabel("Введите email, код из письма и новый пароль");
    infoLabel->setWordWrap(true);
    mainLayout->addWidget(infoLabel);
    
    mainLayout->addSpacing(10);
    
    QFormLayout* formLayout = new QFormLayout();
    
    m_emailEdit = new QLineEdit();
    m_emailEdit->setPlaceholderText("example@mail.com");
    formLayout->addRow("Email:", m_emailEdit);
    
    m_codeEdit = new QLineEdit();
    m_codeEdit->setPlaceholderText("6-значный код из письма");
    formLayout->addRow("Код:", m_codeEdit);
    
    m_newPasswordEdit = new QLineEdit();
    m_newPasswordEdit->setEchoMode(QLineEdit::Password);
    m_newPasswordEdit->setPlaceholderText("Новый пароль (мин. 6 символов)");
    formLayout->addRow("Новый пароль:", m_newPasswordEdit);
    
    mainLayout->addLayout(formLayout);
    
    mainLayout->addSpacing(10);
    
    m_sendCodeBtn = new QPushButton("Отправить код");
    m_resetBtn = new QPushButton("Сбросить пароль");
    
    QHBoxLayout* buttonLayout = new QHBoxLayout();
    buttonLayout->addWidget(m_sendCodeBtn);
    buttonLayout->addWidget(m_resetBtn);
    mainLayout->addLayout(buttonLayout);
    
    m_statusLabel = new QLabel();
    m_statusLabel->setAlignment(Qt::AlignCenter);
    m_statusLabel->setWordWrap(true);
    mainLayout->addWidget(m_statusLabel);
    
    m_backBtn = new QPushButton("Отмена");
    mainLayout->addWidget(m_backBtn);
    
    // Подключаем сигналы
    connect(m_sendCodeBtn, &QPushButton::clicked, this, &ResetPasswordDialog::onSendCode);
    connect(m_resetBtn, &QPushButton::clicked, this, &ResetPasswordDialog::onResetPassword);
    connect(m_backBtn, &QPushButton::clicked, this, &ResetPasswordDialog::reject);
    
    // КНОПКА СБРОСА АКТИВНА СРАЗУ
    m_resetBtn->setEnabled(true);
    m_sendCodeBtn->setEnabled(true);
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
    appendMessage("Отправка запроса... Ждите код в консоли сервера");
}

void ResetPasswordDialog::onResetPassword()
{
    if (!m_socket || m_socket->state() != QAbstractSocket::ConnectedState) {
        appendMessage("Нет подключения к серверу", true);
        return;
    }
    
    QString email = m_emailEdit->text().trimmed();
    QString code = m_codeEdit->text().trimmed();
    QString newPassword = m_newPasswordEdit->text().trimmed();
    
    if (email.isEmpty()) {
        appendMessage("Введите email", true);
        return;
    }
    
    if (code.isEmpty() || code.length() != 6) {
        appendMessage("Введите 6-значный код из письма", true);
        return;
    }
    
    if (newPassword.length() < 6) {
        appendMessage("Пароль должен быть не менее 6 символов", true);
        return;
    }
    
    // Отправляем запрос на сброс пароля
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
        
        qDebug() << "ResetPasswordDialog response:" << response;
        
        if (response.startsWith("FORGOT_SENT|")) {
            appendMessage("✓ Код отправлен! Смотрите консоль сервера.");
            m_sendCodeBtn->setEnabled(true);
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
