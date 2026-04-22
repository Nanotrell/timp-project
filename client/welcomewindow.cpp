#include "welcomewindow.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QFont>
#include <QScrollArea>

WelcomeWindow::WelcomeWindow(QWidget *parent) : QWidget(parent)
{
    setWindowTitle("Function Plotter");
    setMinimumSize(800, 600);
    resize(900, 700);
    setStyleSheet("background-color: #f0f0f0;");

    // Добавляем ScrollArea для всего содержимого
    QScrollArea* scrollArea = new QScrollArea(this);
    scrollArea->setWidgetResizable(true);
    scrollArea->setStyleSheet("background-color: transparent; border: none;");
    
    QWidget* contentWidget = new QWidget();
    QVBoxLayout* mainLayout = new QVBoxLayout(contentWidget);
    mainLayout->setContentsMargins(40, 40, 40, 40);
    mainLayout->setSpacing(20);

    // Заголовок
    QLabel* titleLabel = new QLabel("МИНИСТЕРСТВО НАУКИ И ВЫСШЕГО ОБРАЗОВАНИЯ РФ");
    titleLabel->setAlignment(Qt::AlignCenter);
    titleLabel->setStyleSheet("color: #2c3e50; font-weight: bold;");
    QFont titleFont("Arial", 12);
    titleLabel->setFont(titleFont);
    mainLayout->addWidget(titleLabel);

    QLabel* uniLabel = new QLabel("Московский Политехнический Университет");
    uniLabel->setAlignment(Qt::AlignCenter);
    uniLabel->setStyleSheet("color: #2c3e50; font-weight: bold;");
    QFont uniFont("Arial", 14);
    uniLabel->setFont(uniFont);
    mainLayout->addWidget(uniLabel);

    mainLayout->addSpacing(20);

    // Название проекта
    QLabel* projectLabel = new QLabel("Разработка приложения клиент-сервер");
    projectLabel->setAlignment(Qt::AlignCenter);
    projectLabel->setStyleSheet("color: #e74c3c; font-weight: bold;");
    QFont projectFont("Arial", 16);
    projectLabel->setFont(projectFont);
    mainLayout->addWidget(projectLabel);
    
    QLabel* projectDescLabel = new QLabel("Сервер хранит и обрабатывает данные. Клиент получает результаты расчëтов и отображает их в табличной и графической форме.");
    projectDescLabel->setAlignment(Qt::AlignCenter);
    projectDescLabel->setWordWrap(true);
    projectDescLabel->setStyleSheet("color: #2c3e50;");
    projectDescLabel->setFont(QFont("Arial", 11));
    mainLayout->addWidget(projectDescLabel);

    mainLayout->addSpacing(20);

    // Выполнили
    QLabel* performedLabel = new QLabel("Выполнили студенты группы 251-371:");
    performedLabel->setAlignment(Qt::AlignCenter);
    performedLabel->setStyleSheet("color: #2c3e50; font-weight: bold;");
    performedLabel->setFont(QFont("Arial", 12));
    mainLayout->addWidget(performedLabel);

    QStringList students = {
        "• Мягкая Виктория",
        "• Табакарь Ксения",
        "• Семёнова Эвелина",
        "• Тонковидова Василиса",
        "• Сперанская София"
    };

    for (const QString& student : students) {
        QLabel* studentLabel = new QLabel(student);
        studentLabel->setAlignment(Qt::AlignCenter);
        studentLabel->setStyleSheet("color: #34495e;");
        studentLabel->setFont(QFont("Arial", 11));
        mainLayout->addWidget(studentLabel);
    }

    mainLayout->addSpacing(20);

    // Проверила
    QLabel* checkedLabel = new QLabel("Проверила: Киреева Галина Ивановна");
    checkedLabel->setAlignment(Qt::AlignCenter);
    checkedLabel->setStyleSheet("color: #2c3e50; font-weight: bold;");
    checkedLabel->setFont(QFont("Arial", 11));
    mainLayout->addWidget(checkedLabel);

    QLabel* positionLabel = new QLabel("Доцент кафедры ИБ, МПУ");
    positionLabel->setAlignment(Qt::AlignCenter);
    positionLabel->setStyleSheet("color: #7f8c8d;");
    positionLabel->setFont(QFont("Arial", 10));
    mainLayout->addWidget(positionLabel);

    mainLayout->addStretch();

    // Кнопка "Авторизация"
    m_nextButton = new QPushButton("Авторизация");
    m_nextButton->setFixedSize(200, 45);
    m_nextButton->setStyleSheet(
        "QPushButton {"
        "   background-color: #3498db;"
        "   color: white;"
        "   font-size: 14px;"
        "   font-weight: bold;"
        "   border-radius: 8px;"
        "   border: none;"
        "}"
        "QPushButton:hover {"
        "   background-color: #2980b9;"
        "}"
    );
    mainLayout->addWidget(m_nextButton, 0, Qt::AlignCenter);

    connect(m_nextButton, &QPushButton::clicked, this, &WelcomeWindow::onNextClicked);
    
    scrollArea->setWidget(contentWidget);
    
    QVBoxLayout* outerLayout = new QVBoxLayout(this);
    outerLayout->addWidget(scrollArea);
}

WelcomeWindow::~WelcomeWindow()
{
}

void WelcomeWindow::onNextClicked()
{
    emit nextClicked();
    close();
}
