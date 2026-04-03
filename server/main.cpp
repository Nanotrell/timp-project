#include <QCoreApplication>
#include <QDebug>
#include "postgresqlserver.h"

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    qDebug() << "Запуск Function Plotter Server...";
    PostgreSQLServer server;
    return a.exec();
}
