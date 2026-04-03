#include "math_engine.h"
#include <cmath>

double MathEngine::calculate(double x, const FunctionParams& params)
{
    if (x < 0) {
        return params.a * x * x;
    }
    else if (x >= 0 && x < 2) {
        return (x * x * x) - (3 * x) + params.b;
    }
    else {
        double x4 = x * x * x * x;
        double x3 = x * x * x;
        double x2 = x * x;
        return params.c * (x4 - 4 * x3 + 4 * x2);
    }
}

// 200 точек для плавного графика (диапазон от -20 до 20, шаг 0.2)
QVector<QPointF> MathEngine::generatePoints(const FunctionParams& params, int numPoints)
{
    QVector<QPointF> points;
    points.reserve(numPoints);
    
    double xMin = -20.0;
    double xMax = 20.0;
    double step = (xMax - xMin) / (numPoints - 1);
    
    for (int i = 0; i < numPoints; ++i) {
        double x = xMin + i * step;
        double y = calculate(x, params);
        points.append(QPointF(x, y));
    }
    return points;
}

// 20 точек для таблицы (диапазон от -20 до 20)
QVector<QPointF> MathEngine::generateDisplayPoints(const FunctionParams& params)
{
    QVector<QPointF> points;
    points.reserve(20);
    
    double xMin = -20.0;
    double xMax = 20.0;
    double step = (xMax - xMin) / 19.0;
    
    for (int i = 0; i < 20; ++i) {
        double x = xMin + i * step;
        double y = calculate(x, params);
        points.append(QPointF(x, y));
    }
    return points;
}
