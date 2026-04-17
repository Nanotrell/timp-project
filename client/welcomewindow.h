#ifndef WELCOMEWINDOW_H
#define WELCOMEWINDOW_H

#include <QWidget>
#include <QPushButton>

class FormulaWidget;

class WelcomeWindow : public QWidget
{
    Q_OBJECT

public:
    explicit WelcomeWindow(QWidget *parent = nullptr);
    ~WelcomeWindow();

signals:
    void nextClicked();

private slots:
    void onNextClicked();

private:
    QPushButton* m_nextButton;
    FormulaWidget* m_formulaWidget;
};

#endif // WELCOMEWINDOW_H
