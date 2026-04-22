#include <QApplication>
#include "welcomewindow.h"
#include "taskwindow.h"
#include "authwindow.h"
#include "mainwindow.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // 1. Приветственное окно
    WelcomeWindow welcome;
    
    QObject::connect(&welcome, &WelcomeWindow::nextClicked, [&app]() {
        // 2. Окно авторизации
        AuthWindow* auth = new AuthWindow();
        
        QObject::connect(auth, &AuthWindow::authSuccess, [&app, auth](const QString& login) {
            auth->close();
            // 3. Окно постановки задачи (после авторизации!)
            TaskWindow* task = new TaskWindow();
            
            QObject::connect(task, &TaskWindow::nextClicked, [&app, task, login]() {
                task->close();
                // 4. Главное окно с графиком
                MainWindow* mainWin = new MainWindow(login);
                mainWin->show();
            });
            
            task->show();
        });
        
        auth->show();
    });
    
    welcome.show();
    return app.exec();
}
