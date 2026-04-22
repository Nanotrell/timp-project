#include "taskwindow.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QScrollArea>

TaskWindow::TaskWindow(QWidget *parent) : QWidget(parent)
{
    setWindowTitle("Постановка задачи");
    setMinimumSize(900, 700);
    resize(1000, 750);
    setStyleSheet("background-color: #f5f5f5;");

    QHBoxLayout* mainLayout = new QHBoxLayout(this);
    mainLayout->setContentsMargins(20, 20, 20, 20);
    mainLayout->setSpacing(30);

    // ========== ЛЕВАЯ ЧАСТЬ: ТЕКСТ ЗАДАЧИ ==========
    QScrollArea* leftScroll = new QScrollArea();
    leftScroll->setWidgetResizable(true);
    leftScroll->setStyleSheet("background-color: transparent; border: none;");

    QWidget* leftWidget = new QWidget();
    leftWidget->setStyleSheet("background-color: white; border-radius: 10px;");
    QVBoxLayout* leftLayout = new QVBoxLayout(leftWidget);
    leftLayout->setContentsMargins(20, 20, 20, 20);
    leftLayout->setSpacing(15);

    QLabel* titleLabel = new QLabel("Постановка задачи");
    titleLabel->setStyleSheet("color: #2c3e50; font-weight: bold; font-size: 18px;");
    leftLayout->addWidget(titleLabel);

    QLabel* descLabel = new QLabel(
        "Разработать клиент-серверное приложение для построения графиков "
        "кусочно-заданных математических функций.\n\n"
        "Функция задана тремя участками:\n\n"
        "1. На первом участке (x < 0): f(x) = a * x²\n"
        "2. На втором участке (0 ≤ x < 2): f(x) = x³ - 3x + b\n"
        "3. На третьем участке (x ≥ 2): f(x) = c * (x⁴ - 4x³ + 4x²)\n\n"
        "Параметры a, b, c могут изменяться с помощью ползунков в реальном времени.\n\n"
        "Требования к приложению:\n"
        "• Авторизация и регистрация пользователей\n"
        "• Восстановление пароля по email\n"
        "• Построение графика функции с возможностью масштабирования и панорамирования\n"
        "• Отображение таблицы с 20 рассчитанными значениями\n"
        "• Контейнеризация сервера с помощью Docker\n"
        "• Документирование кода с помощью Doxygen"
    );
    descLabel->setWordWrap(true);
    descLabel->setStyleSheet("color: #34495e; font-size: 12px; line-height: 1.5;");
    leftLayout->addWidget(descLabel);

    leftLayout->addStretch();

    // Кнопка "Далее"
    m_nextButton = new QPushButton("Перейти к графику →");
    m_nextButton->setFixedSize(200, 40);
    m_nextButton->setStyleSheet(
        "QPushButton {"
        "   background-color: #27ae60;"
        "   color: white;"
        "   font-size: 13px;"
        "   font-weight: bold;"
        "   border-radius: 6px;"
        "   border: none;"
        "}"
        "QPushButton:hover {"
        "   background-color: #219a52;"
        "}"
    );
    leftLayout->addWidget(m_nextButton, 0, Qt::AlignCenter);

    leftScroll->setWidget(leftWidget);
    mainLayout->addWidget(leftScroll, 1);

// ========== ПРАВАЯ ЧАСТЬ: ФОРМУЛА (КАРТИНКА) ==========
QWidget* rightWidget = new QWidget();
rightWidget->setFixedSize(450, 300);
rightWidget->setStyleSheet("background-color: white; border: 2px solid #333; border-radius: 10px;");

QVBoxLayout* rightLayout = new QVBoxLayout(rightWidget);
rightLayout->setContentsMargins(10, 10, 10, 10);

QLabel* formulaLabel = new QLabel();
QPixmap pixmap("images/formula.jpg");  // или formula.png
if (!pixmap.isNull()) {
    // Масштабируем под размер виджета
    pixmap = pixmap.scaled(400, 250, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    formulaLabel->setPixmap(pixmap);
} else {
    formulaLabel->setText("Формула не загружена");
    formulaLabel->setStyleSheet("color: red;");
}
formulaLabel->setAlignment(Qt::AlignCenter);

rightLayout->addWidget(formulaLabel);
mainLayout->addWidget(rightWidget);

    connect(m_nextButton, &QPushButton::clicked, this, &TaskWindow::onNextClicked);
}

TaskWindow::~TaskWindow()
{
}

void TaskWindow::onNextClicked()
{
    emit nextClicked();
    close();
}
