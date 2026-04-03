#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QTcpSocket>
#include <QSlider>
#include <QLabel>
#include <QTableWidget>
#include <QTimer>
#include <QVBoxLayout>
#include "plotwidget.h"

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(const QString& login, QWidget *parent = nullptr);
    ~MainWindow();

protected:
    void resizeEvent(QResizeEvent* event) override;

private slots:
    void onParamsChanged();
    void onCalcResponse();
    void onDisconnect();

private:
    void setupUI();
    void sendCalcRequest();
    void updateTable(const QVector<QPointF>& points);
    
    QTcpSocket* m_socket;
    PlotWidget* m_plotWidget;
    QTableWidget* m_tableWidget;
    QSlider* m_sliderA;
    QSlider* m_sliderB;
    QSlider* m_sliderC;
    QLabel* m_labelA;
    QLabel* m_labelB;
    QLabel* m_labelC;
    QVBoxLayout* m_mainLayout;
    QString m_login;
};

#endif // MAINWINDOW_H
