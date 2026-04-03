#include <QApplication>
#include "authwindow.h"
#include "mainwindow.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    
    AuthWindow auth;
    
    // Подключаем сигнал к открытию главного окна
    QObject::connect(&auth, &AuthWindow::authSuccess, [&app](const QString& login) {
        MainWindow* mainWin = new MainWindow(login);
        mainWin->show();
    });
    
    auth.show();
    return app.exec();
}
