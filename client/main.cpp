#include <QApplication>
#include "welcomewindow.h"
#include "authwindow.h"
#include "mainwindow.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // Сначала открываем приветственное окно
    WelcomeWindow welcome;
    
    // После нажатия "Далее" открываем окно авторизации
    QObject::connect(&welcome, &WelcomeWindow::nextClicked, [&app]() {
        AuthWindow* auth = new AuthWindow();
        
        // После успешной авторизации открываем главное окно
        QObject::connect(auth, &AuthWindow::authSuccess, [&app](const QString& login) {
            MainWindow* mainWin = new MainWindow(login);
            mainWin->show();
        });
        
        auth->show();
    });
    
    welcome.show();

    return app.exec();
}
