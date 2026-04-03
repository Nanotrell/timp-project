#ifndef AUTHWINDOW_H
#define AUTHWINDOW_H

#include <QWidget>
#include <QTcpSocket>
#include <QLineEdit>
#include <QPushButton>
#include <QLabel>

class AuthWindow : public QWidget
{
    Q_OBJECT

public:
    explicit AuthWindow(QWidget *parent = nullptr);
    ~AuthWindow();

signals:
    void authSuccess(const QString& login);

private slots:
    void onLogin();
    void onRegister();
    void onConnected();
    void onReadyRead();
    void onError(QAbstractSocket::SocketError);
    void switchToLogin();
    void switchToRegister();
    void onForgotPassword();   // <-- ДОБАВЛЕНА ЭТА СТРОКА

private:
    void sendCommand(const QString& cmd);
    
    QTcpSocket* m_socket;
    bool m_isLoginMode;
    QLineEdit* m_loginEdit;
    QLineEdit* m_passwordEdit;
    QLineEdit* m_emailEdit;
    QPushButton* m_actionButton;
    QPushButton* m_switchButton;
    QLabel* m_statusLabel;
    QLabel* m_emailLabel;
};

#endif // AUTHWINDOW_H
