#include "auth.h"
#include <QCryptographicHash>
#include <QRandomGenerator>

QString hashPassword(const QString& password)
{
    QByteArray hash = QCryptographicHash::hash(password.toUtf8(), QCryptographicHash::Sha256);
    return QString(hash.toHex());
}

bool verifyPassword(const QString& plainPassword, const QString& hashedPassword)
{
    return hashPassword(plainPassword) == hashedPassword;
}

QString generateResetToken()
{
    int code = QRandomGenerator::global()->bounded(100000, 999999);
    return QString::number(code);
}
