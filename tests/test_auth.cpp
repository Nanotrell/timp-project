#include <QtTest>
#include "../server/auth.h"

class TestAuth : public QObject
{
    Q_OBJECT
private slots:
    void test_hashLength() {
        QCOMPARE(hashPassword("test").length(), 64);
    }
    void test_hashConsistency() {
        QString h1 = hashPassword("pass");
        QString h2 = hashPassword("pass");
        QCOMPARE(h1, h2);
    }
    void test_verifyCorrect() {
        QString pass = "123";
        QVERIFY(verifyPassword(pass, hashPassword(pass)));
    }
    void test_tokenLength() {
        QCOMPARE(generateResetToken().length(), 6);
    }
};

QTEST_APPLESS_MAIN(TestAuth)
#include "test_auth.moc"
