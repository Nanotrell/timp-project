#ifndef PLOTWIDGET_H
#define PLOTWIDGET_H

#include <QWidget>
#include <QVector>
#include <QPointF>

class PlotWidget : public QWidget
{
    Q_OBJECT

public:
    explicit PlotWidget(QWidget *parent = nullptr);

    void setPoints(const QVector<QPointF>& points);
    void setFunctionParams(double a, double b, double c);
    void clear();

protected:
    void paintEvent(QPaintEvent* event) override;
    void wheelEvent(QWheelEvent* event) override;
    void mousePressEvent(QMouseEvent* event) override;
    void mouseMoveEvent(QMouseEvent* event) override;
    void mouseReleaseEvent(QMouseEvent* event) override;

private:
    QPointF worldToWidget(const QPointF& point) const;
    QPointF widgetToWorld(const QPointF& point) const;
    void drawAxes(QPainter& painter);
    void drawGrid(QPainter& painter);
    void drawFunction(QPainter& painter);
    void drawFormula(QPainter& painter);

    QVector<QPointF> m_points;
    double m_a = 1.0, m_b = 0.0, m_c = 1.0;

    double m_xMin = -3.0;
    double m_xMax = 5.0;
    double m_yMin = -5.0;
    double m_yMax = 10.0;

    bool m_panning = false;
    QPoint m_lastMousePos;
};

#endif // PLOTWIDGET_H
