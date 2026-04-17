#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QTcpSocket>
#include <QSlider>
#include <QLabel>
#include <QTableWidget>
#include <QTimer>
#include "plotwidget.h"

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(const QString& login, QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void onParamsChanged();
    void onCalcResponse();
    void onDisconnect();

private:
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
    QString m_login;
};

#endif // MAINWINDOW_H
