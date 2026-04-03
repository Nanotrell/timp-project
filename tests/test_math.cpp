#include <QtTest>
#include "../server/math_engine.h"

class TestMathEngine : public QObject
{
    Q_OBJECT

private slots:
    void test_first_region()
    {
        FunctionParams params(2.0, 0.0, 1.0);
        // x < 0: a * x²
        double result = MathEngine::calculate(-1.0, params);
        QCOMPARE(result, 2.0);  // 2 * (-1)² = 2
    }

    void test_second_region()
    {
        FunctionParams params(1.0, 5.0, 1.0);
        // 0 ≤ x < 2: x³ - 3x + b
        double result = MathEngine::calculate(1.0, params);
        QCOMPARE(result, 3.0);  // 1 - 3 + 5 = 3
    }

    void test_third_region()
    {
        FunctionParams params(1.0, 0.0, 2.0);
        // x ≥ 2: c * (x⁴ - 4x³ + 4x²)
        double result = MathEngine::calculate(2.0, params);
        QCOMPARE(result, 0.0);  // 2 * (16 - 32 + 16) = 0
    }
};

QTEST_APPLESS_MAIN(TestMathEngine)
#include "test_math.moc"
