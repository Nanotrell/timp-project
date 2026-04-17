#include "plotwidget.h"
#include <QPainter>
#include <QWheelEvent>
#include <QMouseEvent>
#include <cmath>

PlotWidget::PlotWidget(QWidget *parent) : QWidget(parent)
{
    setMinimumSize(600, 500);
    setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Expanding);
    setBackgroundRole(QPalette::Base);
    setAutoFillBackground(true);
}

void PlotWidget::setPoints(const QVector<QPointF>& points)
{
    m_points = points;
    update();
}

void PlotWidget::setFunctionParams(double a, double b, double c)
{
    m_a = a;
    m_b = b;
    m_c = c;
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

void PlotWidget::drawGrid(QPainter& painter)
{
    painter.setPen(QPen(Qt::lightGray, 1, Qt::DashLine));
    
    for (int x = -3; x <= 5; ++x) {
        painter.drawLine(worldToWidget(QPointF(x, m_yMin)), 
                        worldToWidget(QPointF(x, m_yMax)));
    }
    
    for (int y = -5; y <= 10; ++y) {
        painter.drawLine(worldToWidget(QPointF(m_xMin, y)), 
                        worldToWidget(QPointF(m_xMax, y)));
    }
}

void PlotWidget::drawAxes(QPainter& painter)
{
    painter.setPen(QPen(Qt::black, 2));
    QPointF originW = worldToWidget(QPointF(0, 0));
    
    painter.drawLine(QPointF(0, originW.y()), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(originW.x(), 0), QPointF(originW.x(), height()));
    
    painter.drawLine(QPointF(width()-10, originW.y()-5), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(width()-10, originW.y()+5), QPointF(width(), originW.y()));
    painter.drawLine(QPointF(originW.x()-5, 10), QPointF(originW.x(), 0));
    painter.drawLine(QPointF(originW.x()+5, 10), QPointF(originW.x(), 0));
    
    painter.drawText(width()-15, originW.y()-5, "X");
    painter.drawText(originW.x()+5, 15, "Y");
    
    painter.setPen(QPen(Qt::darkGray, 1));
    for (int x = -3; x <= 5; ++x) {
        if (x != 0) {
            QPointF pos = worldToWidget(QPointF(x, 0));
            painter.drawText(pos.x() - 8, pos.y() + 15, QString::number(x));
        }
    }
    for (int y = -5; y <= 10; ++y) {
        if (y != 0) {
            QPointF pos = worldToWidget(QPointF(0, y));
            painter.drawText(pos.x() + 8, pos.y() + 5, QString::number(y));
        }
    }
}

void PlotWidget::drawFunction(QPainter& painter)
{
    if (m_points.isEmpty()) return;
    
    painter.setPen(QPen(Qt::blue, 2));
    
    QPointF prev = worldToWidget(m_points[0]);
    for (int i = 1; i < m_points.size(); ++i) {
        QPointF curr = worldToWidget(m_points[i]);
        painter.drawLine(prev, curr);
        prev = curr;
    }
}

void PlotWidget::drawFormula(QPainter& painter)
{
    // Прямоугольник для формулы (сдвинут вправо)
    int rectX = width() - 280;
    int rectY = 10;
    int rectW = 270;
    int rectH = 130;
    
    painter.save();
    
    painter.fillRect(rectX, rectY, rectW, rectH, QColor(255, 255, 255, 220));
    painter.setPen(QPen(Qt::black, 1));
    painter.drawRect(rectX, rectY, rectW, rectH);
    
    painter.setFont(QFont("Times New Roman", 10));
    painter.setPen(Qt::black);
    
    int x = rectX + 10;
    int y = rectY + 20;
    
    painter.drawText(x, y, "f(x) =");
    
    // Фигурная скобка
    painter.drawLine(x + 35, y + 5, x + 35, y + 85);
    painter.drawLine(x + 35, y + 5, x + 45, y + 5);
    painter.drawLine(x + 35, y + 85, x + 45, y + 85);
    
    // Уравнения
    painter.drawText(x + 55, y + 15, "a * x²,");
    painter.drawText(x + 150, y + 15, "x < 0");
    
    painter.drawText(x + 55, y + 45, "x³ - 3x + b,");
    painter.drawText(x + 150, y + 45, "0 ≤ x < 2");
    
    painter.drawText(x + 55, y + 75, "c * (x⁴ - 4x³ + 4x²),");
    painter.drawText(x + 150, y + 75, "x ≥ 2");
    
    // Текущие значения параметров
    painter.setFont(QFont("Arial", 9));
    painter.setPen(QPen(Qt::darkBlue, 1));
    painter.drawText(x, y + 105, QString("a = %1   b = %2   c = %3")
                    .arg(m_a, 0, 'f', 2)
                    .arg(m_b, 0, 'f', 2)
                    .arg(m_c, 0, 'f', 2));
    
    painter.restore();
}

void PlotWidget::paintEvent(QPaintEvent*)
{
    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.fillRect(rect(), Qt::white);
    
    drawGrid(painter);
    drawAxes(painter);
    drawFunction(painter);
    drawFormula(painter);
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
