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
    
    // Фиксированный масштаб
    m_xMin = -3.0;
    m_xMax = 5.0;
    m_yMin = -5.0;
    m_yMax = 10.0;
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

void PlotWidget::setNumPoints(int numPoints)
{
    m_numPoints = numPoints;
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

// void PlotWidget::drawFunction(QPainter& painter)
// {
//     if (m_points.isEmpty()) return;
    
//     painter.setPen(QPen(Qt::blue, 2));
    
//     QPointF prev = worldToWidget(m_points[0]);
//     for (int i = 1; i < m_points.size(); ++i) {
//         QPointF curr = worldToWidget(m_points[i]);
//         painter.drawLine(prev, curr);
//         prev = curr;
//     }
// }

void PlotWidget::drawFunction(QPainter& painter)
{
    if (m_points.size() < 2) return;

    // Цвета для трёх веток
    QColor colorBranch1 = QColor(255, 80, 80);   // Красный (x < 0)
    QColor colorBranch2 = QColor(80, 255, 80);   // Зелёный (0 ≤ x < 2)
    QColor colorBranch3 = QColor(80, 80, 255);   // Синий (x ≥ 2)

    // Рисуем сегменты между соседними точками
    for (int i = 1; i < m_points.size(); ++i) {
        const QPointF& p1 = m_points[i - 1];
        const QPointF& p2 = m_points[i];
        
        // Определяем цвет по средней точке сегмента
        double midX = (p1.x() + p2.x()) / 2.0;
        QColor segmentColor;
        if (midX < 0) {
            segmentColor = colorBranch1;
        } else if (midX < 2) {
            segmentColor = colorBranch2;
        } else {
            segmentColor = colorBranch3;
        }
        
        painter.setPen(QPen(segmentColor, 2));
        
        QPointF w1 = worldToWidget(p1);
        QPointF w2 = worldToWidget(p2);
        painter.drawLine(w1, w2);
    }
}

void PlotWidget::drawFormula(QPainter& painter)
{
    int rectX = width() - 250;
    int rectY = 10;
    int rectW = 240;
    int rectH = 180;
    
    painter.save();
    painter.fillRect(rectX, rectY, rectW, rectH, QColor(255, 255, 255, 230));
    painter.setPen(QPen(Qt::black, 1));
    painter.drawRect(rectX, rectY, rectW, rectH);
    
    // Загрузка и отрисовка изображения формулы
    QPixmap pixmap("images/formula.jpg");
    if (!pixmap.isNull()) {
        QPixmap scaledPixmap = pixmap.scaled(rectW - 10, rectH - 40, 
                                              Qt::KeepAspectRatio, 
                                              Qt::SmoothTransformation);
        painter.drawPixmap(rectX + 5, rectY + 5, scaledPixmap);
    } else {
        // Если картинка не загрузилась — рисуем текст
        painter.setFont(QFont("Times New Roman", 9));
        painter.setPen(Qt::black);
        painter.drawText(rectX + 10, rectY + 20, "f(x) =");
        painter.drawText(rectX + 30, rectY + 45, "{ a·x², x < 0");
        painter.drawText(rectX + 30, rectY + 70, "{ x³-3x+b, 0≤x<2");
        painter.drawText(rectX + 30, rectY + 95, "{ c·(x⁴-4x³+4x²), x≥2");
    }
    
    // Параметры
    painter.setFont(QFont("Arial", 8));
    painter.setPen(QPen(Qt::darkBlue, 1));
    painter.drawText(rectX + 10, rectY + 155, 
                     QString("a = %1   b = %2   c = %3")
                     .arg(m_a, 0, 'f', 2)
                     .arg(m_b, 0, 'f', 2)
                     .arg(m_c, 0, 'f', 2));
    
    painter.drawText(rectX + 10, rectY + 170, 
                     QString("Точек: %1").arg(m_numPoints));
    
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

// Масштабирование отключено — пустые обработчики
void PlotWidget::wheelEvent(QWheelEvent* event)
{
    Q_UNUSED(event);
    // Масштабирование отключено
}

void PlotWidget::mousePressEvent(QMouseEvent* event)
{
    Q_UNUSED(event);
    // Панорамирование отключено
}

void PlotWidget::mouseMoveEvent(QMouseEvent* event)
{
    Q_UNUSED(event);
}

void PlotWidget::mouseReleaseEvent(QMouseEvent* event)
{
    Q_UNUSED(event);
}
