#ifndef RESETPASSWORDDIALOG_H
#define RESETPASSWORDDIALOG_H

#include <QDialog>
#include <QTcpSocket>
#include <QLineEdit>
#include <QLabel>
#include <QPushButton>

class ResetPasswordDialog : public QDialog
{
    Q_OBJECT

public:
    explicit ResetPasswordDialog(QWidget *parent = nullptr);
    void setSocket(QTcpSocket* socket) { m_socket = socket; }

public slots:
    void onReadyRead();

private slots:
    void onSendCode();
    void onResetPassword();

private:
    void sendCommand(const QString& cmd);
    void appendMessage(const QString& msg, bool isError = false);
    
    QTcpSocket* m_socket;
    
    QLineEdit* m_emailEdit;
    QLineEdit* m_codeEdit;
    QLineEdit* m_newPasswordEdit;
    QPushButton* m_sendCodeBtn;
    QPushButton* m_resetBtn;
    QLabel* m_statusLabel;
    QPushButton* m_backBtn;
};

#endif // RESETPASSWORDDIALOG_H
