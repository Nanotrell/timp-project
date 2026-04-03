#include "plotwidget.h"
#include <QPainter>
#include <QWheelEvent>
#include <QMouseEvent>
#include <cmath>

PlotWidget::PlotWidget(QWidget *parent) : QWidget(parent)
{
    setMinimumHeight(400);
    setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Expanding);
    setBackgroundRole(QPalette::Base);
    setAutoFillBackground(true);
    
    // Диапазон от -20 до 20 по X, от -20 до 20 по Y (равные оси)
    m_xMin = -20.0;
    m_xMax = 20.0;
    m_yMin = -20.0;
    m_yMax = 20.0;
}

void PlotWidget::setPoints(const QVector<QPointF>& points)
{
    m_points = points;
    update();
}

void PlotWidget::clear()
{
    m_points.clear();
    update();
}

QPointF PlotWidget::worldToWidget(const QPointF& point) const
{
    double x = (point.x() - m_xMin) / (m_xMax - m_xMin) * width();
    double y = height() - (point.y() - m_yMin) / (m_yMax - m_yMin) * height();
    return QPointF(x, y);
}

QPointF PlotWidget::widgetToWorld(const QPointF& point) const
{
    double x = m_xMin + point.x() / width() * (m_xMax - m_xMin);
    double y = m_yMin + (height() - point.y()) / height() * (m_yMax - m_yMin);
    return QPointF(x, y);
}

void PlotWidget::paintEvent(QPaintEvent*)
{
    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.fillRect(rect(), Qt::white);
    
    // Сетка (каждые 5 единиц)
    painter.setPen(QPen(Qt::lightGray, 1, Qt::DashLine));
    for (int x = -20; x <= 20; x += 5) {
        painter.drawLine(worldToWidget(QPointF(x, m_yMin)), worldToWidget(QPointF(x, m_yMax)));
    }
    for (int y = -20; y <= 20; y += 5) {
        painter.drawLine(worldToWidget(QPointF(m_xMin, y)), worldToWidget(QPointF(m_xMax, y)));
    }
    
    // Оси
    painter.setPen(QPen(Qt::black, 2));
    QPointF originW = worldToWidget(QPointF(0, 0));
    painter.drawLine(QPointF(0, originW.y()), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(originW.x(), 0), QPointF(originW.x(), height()));
    
    // Стрелки
    painter.drawLine(QPointF(width()-10, originW.y()-5), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(width()-10, originW.y()+5), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(originW.x()-5, 10), QPointF(originW.x(), 0));
    painter.drawLine(QPointF(originW.x()+5, 10), QPointF(originW.x(), 0));
    
    // Подписи
    painter.drawText(width()-15, originW.y()-5, "X");
    painter.drawText(originW.x()+5, 15, "Y");
    
    // Подписи на осях (каждые 5 единиц)
    painter.setPen(QPen(Qt::darkGray, 1));
    for (int x = -20; x <= 20; x += 5) {
        if (x != 0) {
            QPointF pos = worldToWidget(QPointF(x, 0));
            painter.drawText(pos.x() - 5, pos.y() + 15, QString::number(x));
        }
    }
    for (int y = -20; y <= 20; y += 5) {
        if (y != 0) {
            QPointF pos = worldToWidget(QPointF(0, y));
            painter.drawText(pos.x() + 8, pos.y() + 5, QString::number(y));
        }
    }
    
    // График
    if (m_points.isEmpty()) return;
    
    painter.setPen(QPen(Qt::blue, 2));
    QPointF prev = worldToWidget(m_points[0]);
    for (int i = 1; i < m_points.size(); ++i) {
        QPointF curr = worldToWidget(m_points[i]);
        painter.drawLine(prev, curr);
        prev = curr;
    }
}

void PlotWidget::wheelEvent(QWheelEvent* event)
{
    double scale = (event->angleDelta().y() > 0) ? 0.9 : 1.1;
    QPointF mouseWorld = widgetToWorld(event->position());
    double newWidth = (m_xMax - m_xMin) * scale;
    double newHeight = (m_yMax - m_yMin) * scale;
    m_xMin = mouseWorld.x() - (mouseWorld.x() - m_xMin) * scale;
    m_xMax = m_xMin + newWidth;
    m_yMin = mouseWorld.y() - (mouseWorld.y() - m_yMin) * scale;
    m_yMax = m_yMin + newHeight;
    update();
}

void PlotWidget::mousePressEvent(QMouseEvent* event)
{
    if (event->button() == Qt::LeftButton) {
        m_panning = true;
        m_lastMousePos = event->pos();
        setCursor(Qt::ClosedHandCursor);
    }
}

void PlotWidget::mouseMoveEvent(QMouseEvent* event)
{
    if (m_panning) {
        QPoint delta = event->pos() - m_lastMousePos;
        double dx = (delta.x() / (double)width()) * (m_xMax - m_xMin);
        double dy = (delta.y() / (double)height()) * (m_yMax - m_yMin);
        m_xMin -= dx;
        m_xMax -= dx;
        m_yMin += dy;
        m_yMax += dy;
        m_lastMousePos = event->pos();
        update();
    }
}

void PlotWidget::mouseReleaseEvent(QMouseEvent* event)
{
    if (event->button() == Qt::LeftButton) {
        m_panning = false;
        setCursor(Qt::ArrowCursor);
    }
}
