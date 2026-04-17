#include "welcomewindow.h"
#include "formulawidget.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QScrollArea>

WelcomeWindow::WelcomeWindow(QWidget *parent) : QWidget(parent)
{
    setWindowTitle("Добро пожаловать");
    setMinimumSize(800, 550);
    resize(1000, 650);
    setStyleSheet("background-color: #2c3e50;");

    QHBoxLayout* mainLayout = new QHBoxLayout(this);
    mainLayout->setContentsMargins(20, 20, 20, 20);
    mainLayout->setSpacing(30);

    // Левая часть
    QScrollArea* leftScroll = new QScrollArea();
    leftScroll->setWidgetResizable(true);
    leftScroll->setStyleSheet("background-color: transparent; border: none;");
    
    QWidget* leftWidget = new QWidget();
    leftWidget->setStyleSheet("background-color: transparent;");
    QVBoxLayout* leftLayout = new QVBoxLayout(leftWidget);
    leftLayout->setSpacing(15);
    leftLayout->setContentsMargins(10, 10, 10, 10);

    QLabel* titleLabel = new QLabel("Проект: Графическое отображение ветвящейся функции\nв рамках клиент-серверного проекта");
    titleLabel->setWordWrap(true);
    titleLabel->setStyleSheet("color: white; font-weight: bold;");
    QFont titleFont("Arial", 14, QFont::Bold);
    titleLabel->setFont(titleFont);
    leftLayout->addWidget(titleLabel);

    leftLayout->addSpacing(10);

    QLabel* disciplineLabel = new QLabel("Дисциплина: Технологии и методы программирования");
    disciplineLabel->setWordWrap(true);
    disciplineLabel->setStyleSheet("color: #ecf0f1;");
    QFont disciplineFont("Arial", 12);
    disciplineLabel->setFont(disciplineFont);
    leftLayout->addWidget(disciplineLabel);

    leftLayout->addSpacing(10);

    QLabel* descLabel = new QLabel("Описание проекта: Проект представляет собой клиент-серверное приложение для построения графиков математических функций.");
    descLabel->setWordWrap(true);
    descLabel->setStyleSheet("color: #ecf0f1;");
    descLabel->setFont(disciplineFont);
    leftLayout->addWidget(descLabel);

    leftLayout->addSpacing(20);

    QLabel* membersTitle = new QLabel("Участники проекта, студенты группы 251-371:");
    membersTitle->setStyleSheet("color: white;");
    membersTitle->setFont(QFont("Arial", 12, QFont::Bold));
    leftLayout->addWidget(membersTitle);

    QStringList members = {
        "• Мягкая Виктория",
        "• Табакарь Ксения",
        "• Семёнова Эвелина",
        "• Тонковидова Василиса",
        "• Сперанская София"
    };

    for (const QString& member : members) {
        QLabel* memberLabel = new QLabel(member);
        memberLabel->setStyleSheet("color: #bdc3c7;");
        memberLabel->setFont(QFont("Arial", 11));
        leftLayout->addWidget(memberLabel);
    }

    leftLayout->addStretch();

    m_nextButton = new QPushButton("Далее →");
    m_nextButton->setFixedSize(200, 40);
    m_nextButton->setStyleSheet(
        "QPushButton {"
        "   background-color: #3498db;"
        "   color: white;"
        "   font-size: 14px;"
        "   font-weight: bold;"
        "   border-radius: 5px;"
        "   border: none;"
        "}"
        "QPushButton:hover {"
        "   background-color: #2980b9;"
        "}"
    );
    leftLayout->addWidget(m_nextButton, 0, Qt::AlignCenter);
    
    leftScroll->setWidget(leftWidget);
    mainLayout->addWidget(leftScroll, 1);

    // Правая часть - формула
    m_formulaWidget = new FormulaWidget(this);
    mainLayout->addWidget(m_formulaWidget);

    connect(m_nextButton, &QPushButton::clicked, this, &WelcomeWindow::onNextClicked);
}

WelcomeWindow::~WelcomeWindow()
{
}

void WelcomeWindow::onNextClicked()
{
    emit nextClicked();
    close();
}
