#ifndef FORMULAWIDGET_H
#define FORMULAWIDGET_H

#include <QWidget>

class FormulaWidget : public QWidget
{
    Q_OBJECT

public:
    explicit FormulaWidget(QWidget *parent = nullptr);

protected:
    void paintEvent(QPaintEvent* event) override;
};

#endif // FORMULAWIDGET_H
