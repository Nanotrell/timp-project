#include <QtTest>
#include "../server/math_engine.h"

class TestMathEngine : public QObject
{
    Q_OBJECT
private slots:
    void test_first_region() {
        FunctionParams params(2.0, 0.0, 1.0);
        QCOMPARE(MathEngine::calculate(-2.0, params), 8.0);
    }
    void test_second_region() {
        FunctionParams params(1.0, 5.0, 1.0);
        QCOMPARE(MathEngine::calculate(1.0, params), 3.0);
    }
    void test_third_region() {
        FunctionParams params(1.0, 0.0, 2.0);
        QCOMPARE(MathEngine::calculate(3.0, params), 18.0);
    }
    void test_generatePoints() {
        FunctionParams params(1.0, 0.0, 1.0);
        QCOMPARE(MathEngine::generatePoints(params, 200).size(), 200);
    }
};

QTEST_APPLESS_MAIN(TestMathEngine)
#include "test_math_engine.moc"
