#ifndef TASKWINDOW_H
#define TASKWINDOW_H

#include <QWidget>
#include <QPushButton>

class TaskWindow : public QWidget
{
    Q_OBJECT

public:
    explicit TaskWindow(QWidget *parent = nullptr);
    ~TaskWindow();

signals:
    void nextClicked();

private slots:
    void onNextClicked();

private:
    QPushButton* m_nextButton;
};

#endif // TASKWINDOW_H
