#ifndef AUTH_H
#define AUTH_H

#include <QString>

QString hashPassword(const QString& password);
bool verifyPassword(const QString& plainPassword, const QString& hashedPassword);
QString generateResetToken();

#endif // AUTH_H
