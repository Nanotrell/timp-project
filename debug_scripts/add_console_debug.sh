#!/bin/bash
# ============================================================================
# СКРИПТ ДЛЯ ДОБАВЛЕНИЯ ОТЛАДКИ КОДА ВОССТАНОВЛЕНИЯ ПАРОЛЯ В КОНСОЛЬ СЕРВЕРА
# ============================================================================

set -e

echo "=========================================="
echo "  ДОБАВЛЕНИЕ ОТЛАДКИ КОДА В КОНСОЛЬ СЕРВЕРА"
echo "=========================================="

PROJECT_DIR=~/projects/function-plotter
cd $PROJECT_DIR

# ============================================================================
# 1. СОЗДАЕМ РЕЗЕРВНУЮ КОПИЮ
# ============================================================================
echo ""
echo "1. Создание резервной копии..."

if [ -f server/postgresqlserver.cpp.bak ]; then
    echo "   Резервная копия уже существует"
else
    cp server/postgresqlserver.cpp server/postgresqlserver.cpp.bak
    echo "   ✅ Резервная копия создана"
fi

# ============================================================================
# 2. ДОБАВЛЯЕМ #include <QRegularExpression> В НАЧАЛО ФАЙЛА
# ============================================================================
echo ""
echo "2. Добавление QRegularExpression..."

if ! grep -q "#include <QRegularExpression>" server/postgresqlserver.cpp; then
    sed -i '1i#include <QRegularExpression>' server/postgresqlserver.cpp
    echo "   ✅ Добавлен #include <QRegularExpression>"
else
    echo "   ✅ QRegularExpression уже есть"
fi

# ============================================================================
# 3. РУЧНАЯ ЗАМЕНА ФУНКЦИИ sendEmail (через временный файл)
# ============================================================================
echo ""
echo "3. Замена функции sendEmail..."

# Создаем временный файл с исправленной функцией
cat > /tmp/sendemail_fixed.txt << 'ENDOFFUNCTION'
void sendEmail(const QString& to, const QString& subject, const QString& body) {
    qDebug() << "========================================";
    qDebug() << "📧 Email to:" << to;
    qDebug() << "   Subject:" << subject;
    qDebug() << "   Body:" << body;
    qDebug() << "========================================";

    // Для теста: извлекаем код из тела письма
    QRegularExpression re("(\\d{6})");
    QRegularExpressionMatch match = re.match(body);
    if (match.hasMatch()) {
        qDebug() << "🔑 КОД ДЛЯ ВОССТАНОВЛЕНИЯ:" << match.captured(1);
        qDebug() << "========================================";
    }
}
ENDOFFUNCTION

# Удаляем старую функцию sendEmail и вставляем новую
# Используем более простой подход - создаем новый файл с заменой
python3 << 'PYTHON_SCRIPT'
import re

file_path = "server/postgresqlserver.cpp"
with open(file_path, 'r') as f:
    content = f.read()

# Находим старую функцию sendEmail и заменяем
pattern = r'void sendEmail\([^)]+\)\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}'
replacement = '''void sendEmail(const QString& to, const QString& subject, const QString& body) {
    qDebug() << "========================================";
    qDebug() << "📧 Email to:" << to;
    qDebug() << "   Subject:" << subject;
    qDebug() << "   Body:" << body;
    qDebug() << "========================================";

    // Для теста: извлекаем код из тела письма
    QRegularExpression re("(\\\\d{6})");
    QRegularExpressionMatch match = re.match(body);
    if (match.hasMatch()) {
        qDebug() << "🔑 КОД ДЛЯ ВОССТАНОВЛЕНИЯ:" << match.captured(1);
        qDebug() << "========================================";
    }
}'''

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(file_path, 'w') as f:
    f.write(new_content)
    print("   ✅ Функция sendEmail обновлена")
PYTHON_SCRIPT

# ============================================================================
# 4. ДОБАВЛЯЕМ ФУНКЦИЮ generateCode ЕСЛИ ЕЁ НЕТ
# ============================================================================
echo ""
echo "4. Проверка функции generateCode..."

if ! grep -q "QString generateCode()" server/postgresqlserver.cpp; then
    # Добавляем функцию generateCode после includes
    sed -i '/#include <QRegularExpression>/a \nQString generateCode() {\n    int code = QRandomGenerator::global()->bounded(100000, 999999);\n    return QString::number(code);\n}\n' server/postgresqlserver.cpp
    echo "   ✅ Функция generateCode добавлена"
else
    echo "   ✅ Функция generateCode уже есть"
fi

# ============================================================================
# 5. ДОБАВЛЯЕМ НЕОБХОДИМЫЕ INCLUDE
# ============================================================================
echo ""
echo "5. Добавление необходимых include..."

if ! grep -q "#include <QRandomGenerator>" server/postgresqlserver.cpp; then
    sed -i '1i#include <QRandomGenerator>' server/postgresqlserver.cpp
    echo "   ✅ Добавлен #include <QRandomGenerator>"
fi

# ============================================================================
# 6. ПЕРЕСБОРКА СЕРВЕРА
# ============================================================================
echo ""
echo "6. Пересборка сервера..."

cd $PROJECT_DIR/server
make clean 2>/dev/null
qmake server.pro 2>/dev/null
make -j$(nproc) 2>/dev/null

if [ $? -eq 0 ]; then
    echo "   ✅ Сервер успешно пересобран"
else
    echo "   ❌ Ошибка сборки сервера"
    echo "   Пробуем исправить вручную..."

    # Проверяем наличие всех необходимых includes
    if ! grep -q "#include <QRegularExpression>" postgresqlserver.cpp; then
        sed -i '1i#include <QRegularExpression>' postgresqlserver.cpp
    fi
    if ! grep -q "#include <QRandomGenerator>" postgresqlserver.cpp; then
        sed -i '1i#include <QRandomGenerator>' postgresqlserver.cpp
    fi

    make -j$(nproc)
    if [ $? -eq 0 ]; then
        echo "   ✅ Сервер успешно пересобран после исправления"
    else
        echo "   ❌ Ошибка сборки. Восстанавливаем резервную копию..."
        cp postgresqlserver.cpp.bak postgresqlserver.cpp
        exit 1
    fi
fi

# ============================================================================
# 7. СОЗДАЕМ ТЕСТОВЫЙ СКРИПТ
# ============================================================================
echo ""
echo "7. Создание тестового скрипта..."

cat > ~/projects/function-plotter/test_forgot.sh << 'EOF'
#!/bin/bash
echo "=========================================="
echo "  ТЕСТИРОВАНИЕ ВОССТАНОВЛЕНИЯ ПАРОЛЯ"
echo "=========================================="
echo ""
echo "1. Запустите сервер в другом терминале:"
echo "   cd ~/projects/function-plotter/server && ./server"
echo ""
echo "2. Запустите клиент:"
echo "   cd ~/projects/function-plotter/client && ./client"
echo ""
echo "3. Нажмите 'Забыли пароль?'"
echo ""
echo "4. Введите email зарегистрированного пользователя"
echo ""
echo "5. Посмотрите в терминал с сервером - там появится код"
echo ""
echo "6. Введите код и новый пароль в клиенте"
echo ""
echo "=========================================="
EOF

chmod +x ~/projects/function-plotter/test_forgot.sh
echo "   ✅ Тестовый скрипт создан"

# ============================================================================
# 8. ИНСТРУКЦИЯ
# ============================================================================
echo ""
echo "=========================================="
echo "  ГОТОВО!"
echo "=========================================="
echo ""
echo "✅ Что сделано:"
echo "   - Добавлен #include <QRegularExpression>"
echo "   - Добавлен #include <QRandomGenerator>"
echo "   - Обновлена функция sendEmail (выводит код в консоль)"
echo "   - Добавлена функция generateCode"
echo "   - Сервер пересобран"
echo ""
echo "🚀 ЗАПУСК:"
echo ""
echo "   # Запустите сервер:"
echo "   cd ~/projects/function-plotter/server"
echo "   ./server"
echo ""
echo "   # В другом терминале запустите клиент:"
echo "   cd ~/projects/function-plotter/client"
echo "   ./client"
echo ""
echo "📋 ТЕСТИРОВАНИЕ:"
echo ""
echo "   1. В клиенте нажмите 'Забыли пароль?'"
echo "   2. Введите email зарегистрированного пользователя"
echo "   3. Посмотрите в терминал с сервером - там появится код"
echo "   4. Введите этот код в клиенте"
echo "   5. Введите новый пароль"
echo ""
echo "=========================================="
