#include "formulawidget.h"
#include <QPainter>

FormulaWidget::FormulaWidget(QWidget *parent) : QWidget(parent)
{
    setFixedSize(400, 500);
    setStyleSheet("background-color: white; border: 1px solid #ccc; border-radius: 5px;");
}

void FormulaWidget::paintEvent(QPaintEvent* event)
{
    Q_UNUSED(event);
    
    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);
    
    painter.fillRect(0, 0, width(), height(), Qt::white);
    painter.setPen(QPen(Qt::black, 2));
    painter.drawRect(0, 0, width() - 1, height() - 1);
    
    painter.setPen(QPen(Qt::black));
    painter.setFont(QFont("Times New Roman", 12));
    
    int x = 30;
    int y = 40;
    
    painter.drawText(x, y, "f(x) =");
    
    painter.drawLine(x + 45, y + 5, x + 45, y + 145);
    painter.drawLine(x + 45, y + 5, x + 55, y + 5);
    painter.drawLine(x + 45, y + 145, x + 55, y + 145);
    
    painter.drawText(x + 65, y + 20, "a * x²,");
    painter.drawText(x + 200, y + 20, "x < 0");
    
    painter.drawText(x + 65, y + 65, "x³ - 3x + b,");
    painter.drawText(x + 200, y + 65, "0 ≤ x < 2");
    
    painter.drawText(x + 65, y + 110, "c * (x⁴ - 4x³ + 4x²),");
    painter.drawText(x + 200, y + 110, "x ≥ 2");
}
