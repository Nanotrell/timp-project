# Диаграмма классов проекта

## 1. Общая архитектура

Проект представляет собой клиент-серверное приложение для построения графиков математических функций. Серверная часть написана на C++ с использованием фреймворка Qt и базы данных PostgreSQL.

### Основные компоненты:

| Компонент            | Назначение                                                                               |
| -------------------- | ---------------------------------------------------------------------------------------- |
| **PostgreSQLServer** | Слушает входящие TCP-подключения, принимает команды от клиентов                          |
| **Database**         | Единственный экземпляр для всей программы, подключается к PostgreSQL и выполняет запросы |
| **MathEngine**       | Статический класс для вычисления функций и генерации точек                               |
| **AuthUtils**        | Утилиты для хэширования паролей и генерации токенов                                      |

## 2. Диаграмма классов

*Класс Database реализует паттерн Singleton. MathEngine содержит только статические методы.*

## 3. Взаимодействие классов

### 3.1. Схема взаимодействия
Клиент (client.exe) ──TCP──► PostgreSQLServer ──┬──► Database ──► PostgreSQL
                                               │
                                               └──► MathEngine (вычисление точек)
###                                                └──► MathEngine (вычисление точек)

### Сервер и база данных (Database)

Сервер не работает с базой данных напрямую. Вместо этого он вызывает методы класса **Database**, который является «одиночкой» (Singleton). Это значит, что в программе существует ровно один объект Database, и все части сервера используют его.

**Что Database умеет делать:**

- Проверять логин и пароль (`checkAuth`)

- Добавлять нового пользователя (`addUser`)

- Сохранять и проверять токены для восстановления пароля

- Выполнять любые SQL-запросы (метод `executeQuery`)


###  Сервер и вычисление функции(MathEngine)

Когда клиент хочет построить график, сервер вызывает методы **MathEngine**. Этот класс не хранит состояние — он просто вычисляет по формулам.

**Что MathEngine умеет делать:**

- Вычислять значение функции в одной точке (`calculate`)

- Генерировать массив из N точек для всего графика (`generatePoints`)

- Генерировать 20 точек для таблицы в клиенте (`generateDisplayPoints`)


Функция имеет вид: **f(x) = a·x² + b·x + c**

###  Сервер и клиент

Общение происходит через **TCP-сокеты**. Клиент отправляет текстовые команды, сервер отвечает.

**Пример диалога:**

- Клиент: `PLOT a=1,b=0,c=1` → Сервер вычисляет точки через MathEngine и возвращает JSON

- Клиент: `LOGIN user pass` → Сервер проверяет через Database и отвечает `OK` или `ERROR`
## 4. Список классов с описанием методов

### 4.1. Database

| Метод | Возвращает | Описание |
|-------|------------|----------|
| `getInstance()` | `Database*` | Получение единственного экземпляра |
| `connect(host, dbName, user, pass, port)` | `bool` | Подключение к PostgreSQL |
| `addUser(login, passHash, email)` | `bool` | Регистрация пользователя |
| `checkAuth(login, passHash)` | `bool` | Проверка учётных данных |
| `setResetToken(email, token, minutes)` | `bool` | Установка токена восстановления |
| `executeQuery(queryStr)` | `QSqlQuery` | Выполнение произвольного SQL |

#### Заголовочный файл класса


	#ifndef DATABASE_H
	#define DATABASE_H

	#include <QSqlDatabase>
	#include <QSqlQuery>
	#include <QString>
	#include <QDateTime>

	// Структура для хранения информации о пользователе
	struct UserInfo {
	    int id;
	    QString login;
	    QString password;      // Хранится в виде хэша
	    QString email;
	    QString resetToken;
	    QDateTime resetTokenExpires;
	    QDateTime createdAt;
	};

	class Database
	{
	private:
	    static Database* instance;   // единственный экземпляр
	    QSqlDatabase db;             // объект подключения к БД

	    Database();                              // приватный конструктор
	    Database(const Database&) = delete;      // запрещаем копирование
	    Database& operator=(const Database&) = delete;

	    void createTables();        // создаёт таблицы, если их нет
	    void updateTables();        // обновляет структуру таблиц

	public:
	    ~Database();
	    static Database* getInstance();   // получить единственный экземпляр

	    bool connect(const QString& host, const QString& dbName,
	                 const QString& user, const QString& password, int port = 5432);
	    bool isOpen() const;
	    void close();

	    // Операции с пользователями
	    bool addUser(const QString& login, const QString& passwordHash, const QString& email);
	    bool userExists(const QString& login);
	    bool emailExists(const QString& email);
	    bool checkAuth(const QString& login, const QString& passwordHash);
	    UserInfo getUserInfo(const QString& login);
	    UserInfo getUserInfoByEmail(const QString& email);
	    bool updatePassword(const QString& login, const QString& newPasswordHash);

	    // Восстановление пароля
	    bool setResetToken(const QString& email, const QString& token, int expiresMinutes = 15);
	    QString getEmailByResetToken(const QString& token);
	    bool isValidResetToken(const QString& token);
	    bool clearResetToken(const QString& token);

	    QSqlQuery executeQuery(const QString& queryStr);
	};

	#endif // DATABASE_H


### 4.2. MathEngine

| Метод | Возвращает | Описание |
|-------|------------|----------|
| `calculate(x, params)` | `double` | Вычисление a*x² + b*x + c |
| `generatePoints(params, numPoints)` | `QVector<QPointF>` | Генерация точек для графика |
| `generateDisplayPoints(params)` | `QVector<QPointF>` | Генерация точек для отображения |
#### Заголовочный файл класса


	#ifndef MATH_ENGINE_H
	#define MATH_ENGINE_H

	#include <QVector>
	#include <QPointF>

	// Структура для хранения трёх параметров функции
	struct FunctionParams {
	    double a;  // коэффициент при x² (для x < 0)
	    double b;  // свободный член (для 0 ≤ x < 2)
	    double c;  // коэффициент для старшей степени (для x ≥ 2)

	    // Конструктор по умолчанию
	    FunctionParams() : a(1.0), b(0.0), c(1.0) {}

	    // Конструктор с параметрами
	    FunctionParams(double aVal, double bVal, double cVal) : a(aVal), b(bVal), c(cVal) {}
	};

	class MathEngine
	{
	public:
	    static double calculate(double x, const FunctionParams& params);
	    static QVector<QPointF> generatePoints(const FunctionParams& params, int numPoints = 200);
	    static QVector<QPointF> generateDisplayPoints(const FunctionParams& params);
	};

	#endif // MATH_ENGINE_H

### 4.3. AuthUtils (Функции)

| Функция | Возвращает | Описание |
|---------|------------|----------|
| `hashPassword(password)` | `QString` | Хэширование пароля |
| `verifyPassword(plain, hashed)` | `bool` | Проверка пароля |
| `generateResetToken()` | `QString` | Генерация случайного токена |

#### Заголовочный файл хэширования

	#ifndef AUTH_H
	#define AUTH_H

	#include <QString>

	QString hashPassword(const QString& password);
	bool verifyPassword(const QString& plainPassword, const QString& hashedPassword);
	QString generateResetToken();

	#endif // AUTH_H

### 4.4. PostgreSQLServer

| Метод | Назначение |
|-------|------------|
| `onNewConnection()` | Обработка нового клиента |
| `onReadyRead()` | Чтение данных от клиента |
| `processRequest(client, request)` | Разбор и выполнение команд |
| `sendJsonPoints(client, params)` | Отправка точек графика в формате JSON |

#### Заголовочный файл TCP-сервера


	#ifndef POSTGRESQLSERVER_H
	#define POSTGRESQLSERVER_H

	#include <QObject>
	#include <QTcpServer>
	#include <QTcpSocket>
	#include <QMap>

	// Структура для хранения состояния клиента
	struct ClientSession {
	    QString buffer;        // накопленные данные от клиента (до символа \n)
	    QString currentLogin;  // логин авторизованного клиента
	};

	class PostgreSQLServer : public QObject
	{
	    Q_OBJECT

	public:
	    explicit PostgreSQLServer(QObject *parent = nullptr);
	    ~PostgreSQLServer();

	private slots:
	    void onNewConnection();      // новый клиент подключился
	    void onReadyRead();          // клиент прислал данные
	    void onClientDisconnected(); // клиент отключился

	private:
	    void processRequest(QTcpSocket* client, const QString& request);
	    void sendResponse(QTcpSocket* client, const QString& response);

	    QTcpServer* m_server;                        // серверный сокет
	    QMap<QTcpSocket*, ClientSession> m_clients;  // клиенты и их состояния
	};

	#endif // POSTGRESQLSERVER_H


## 5. Типы данных

### UserInfo (struct)
Хранит информацию о пользователе: id, login, email, хэш пароля, токен восстановления.

### FunctionParams (struct)
Хранит коэффициенты функции: a, b, c для формулы a·x² + b·x + c.

### ClientSession (struct)
Хранит состояние клиента: буфер входящих данных и текущий логин.

## 6. Внешние зависимости

- **Qt Framework** — QTcpServer, QTcpSocket, QSqlDatabase
- **PostgreSQL** — система управления базами данных
- **libpq** — драйвер PostgreSQL для Qt

## 7. Примечания

- База данных запускается в Docker-контейнере
- Сервер собирается с помощью qmake/Makefile
- Клиент (`client.exe`) поставляется в архиве `release.rar`
- Пароли хранятся в БД в виде хэшей (не в открытом виде)
