#ifndef MATH_ENGINE_H
#define MATH_ENGINE_H

#include <QVector>
#include <QPointF>

struct FunctionParams {
    double a;
    double b;
    double c;

    FunctionParams() : a(1.0), b(0.0), c(1.0) {}
    FunctionParams(double aVal, double bVal, double cVal) : a(aVal), b(bVal), c(cVal) {}
};

class MathEngine
{
public:
    static double calculate(double x, const FunctionParams& params);
    static QVector<QPointF> generatePoints(const FunctionParams& params, int numPoints = 200);
    static QVector<QPointF> generateDisplayPoints(const FunctionParams& params);
};

#endif // MATH_ENGINE_H
