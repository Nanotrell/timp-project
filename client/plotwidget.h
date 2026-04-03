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
    
    QVector<QPointF> m_points;
    double m_xMin = -20.0;
    double m_xMax = 20.0;
    double m_yMin = -20.0;
    double m_yMax = 20.0;
    bool m_panning = false;
    QPoint m_lastMousePos;
};

#endif // PLOTWIDGET_H
