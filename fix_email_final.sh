#!/bin/bash
# ============================================================================
# ПОЛНЫЙ СКРИПТ: ИСПРАВЛЕНИЕ ОТПРАВКИ EMAIL (send_email.py в Docker)
# ============================================================================

set -e

PROJECT_DIR=~/projects/function-plotter-copy/timp-project
cd $PROJECT_DIR

echo "=========================================="
echo "  ИСПРАВЛЕНИЕ ОТПРАВКИ EMAIL"
echo "=========================================="

# ============================================================================
# 1. ПРОВЕРКА СУЩЕСТВОВАНИЯ send_email.py
# ============================================================================
echo ""
echo "1. Проверка файла send_email.py..."

if [ -f "server/send_email.py" ]; then
    echo "   ✅ send_email.py существует"
else
    echo "   ❌ send_email.py отсутствует, создаём..."
    
    cat > server/send_email.py << 'EOF'
#!/usr/bin/env python3
import smtplib
import sys
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def send_email(to_email, subject, body):
    smtp_host = os.environ.get('SMTP_HOST', 'smtp.gmail.com')
    smtp_port = int(os.environ.get('SMTP_PORT', 587))
    smtp_user = os.environ.get('SMTP_USER', '')
    smtp_password = os.environ.get('SMTP_PASSWORD', '')
    from_email = os.environ.get('FROM_EMAIL', smtp_user)
    
    if not smtp_user or not smtp_password:
        print("ERROR: SMTP not configured")
        return False
    
    try:
        msg = MIMEMultipart()
        msg['From'] = from_email
        msg['To'] = to_email
        msg['Subject'] = subject
        msg.attach(MIMEText(body, 'html'))
        
        server = smtplib.SMTP(smtp_host, smtp_port)
        server.starttls()
        server.login(smtp_user, smtp_password)
        server.send_message(msg)
        server.quit()
        
        print("OK")
        return True
    except Exception as e:
        print(f"ERROR: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) >= 4:
        success = send_email(sys.argv[1], sys.argv[2], sys.argv[3])
        sys.exit(0 if success else 1)
    else:
        print("Usage: send_email.py to subject body")
        sys.exit(1)
EOF
    chmod +x server/send_email.py
    echo "   ✅ send_email.py создан"
fi

# ============================================================================
# 2. ОБНОВЛЕНИЕ DOCKERFILE
# ============================================================================
echo ""
echo "2. Обновление Dockerfile (добавление send_email.py и Python)..."

cat > server/Dockerfile << 'EOF'
FROM ubuntu:22.04

ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get install -y \
    qtbase5-dev \
    qtchooser \
    qt5-qmake \
    qtbase5-dev-tools \
    build-essential \
    libqt5sql5 \
    libqt5sql5-psql \
    libpq-dev \
    postgresql-client \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/server/

COPY *.cpp /root/server/
COPY *.h /root/server/
COPY *.pro /root/server/
COPY send_email.py /root/server/

RUN qmake server.pro && make

EXPOSE 33333

ENTRYPOINT ["./server"]
EOF

echo "   ✅ Dockerfile обновлен"

# ============================================================================
# 3. ОБНОВЛЕНИЕ POSTGRESQLSERVER.CPP
# ============================================================================
echo ""
echo "3. Обновление функции sendEmail..."

# Создаем временный файл с правильной функцией
cat > /tmp/sendemail_func.txt << 'EOF'
void sendEmail(const QString& to, const QString& subject, const QString& body)
{
    qDebug() << "========================================";
    qDebug() << "📧 Email to:" << to;
    
    QRegularExpression re("(\\d{6})");
    QRegularExpressionMatch match = re.match(body);
    QString code = match.hasMatch() ? match.captured(1) : "???";
    qDebug() << "🔑 Код:" << code;
    
    QString smtpUser = qgetenv("SMTP_USER");
    if (smtpUser.isEmpty() || smtpUser == "your-email@gmail.com") {
        qDebug() << "⚠️ SMTP не настроен! Код для теста:" << code;
        qDebug() << "========================================";
        return;
    }
    
    // Вызов Python скрипта для отправки
    QString cmd = QString("python3 /root/server/send_email.py \"%1\" \"%2\" \"%3\" 2>&1")
                      .arg(to, subject, body);
    
    FILE* pipe = popen(cmd.toUtf8(), "r");
    if (!pipe) {
        qDebug() << "⚠️ Не удалось запустить Python скрипт";
        return;
    }
    
    char buffer[256];
    QString result;
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        result += buffer;
    }
    int exitCode = pclose(pipe);
    
    if (exitCode == 0 && result.contains("OK")) {
        qDebug() << "✅ Email отправлен на" << to;
    } else {
        qDebug() << "⚠️ Ошибка отправки:" << result.trimmed();
        qDebug() << "⚠️ Используйте код для теста:" << code;
    }
    qDebug() << "========================================";
}
EOF

# Проверяем, есть ли уже функция sendEmail в файле
if grep -q "void sendEmail" server/postgresqlserver.cpp; then
    # Заменяем существующую функцию
    sed -i '/void sendEmail/,/^}/c\'"$(cat /tmp/sendemail_func.txt | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')" server/postgresqlserver.cpp 2>/dev/null || {
        echo "   ⚠️ Автоматическая замена не удалась, добавляем функцию вручную..."
        # Вставляем перед последней }
        sed -i '$i\'"$(cat /tmp/sendemail_func.txt)" server/postgresqlserver.cpp
    }
    echo "   ✅ Функция sendEmail обновлена"
else
    # Добавляем функцию перед последней }
    sed -i '$i\'"$(cat /tmp/sendemail_func.txt)" server/postgresqlserver.cpp
    echo "   ✅ Функция sendEmail добавлена"
fi

rm -f /tmp/sendemail_func.txt

# ============================================================================
# 4. ОБНОВЛЕНИЕ .ENV
# ============================================================================
echo ""
echo "4. Обновление .env файла..."

if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=plotter_user
POSTGRES_PASSWORD=plotter123
POSTGRES_DB=function_plotter

# SMTP - ЗАМЕНИТЕ НА СВОИ ДАННЫЕ!
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=krasnovav932@gmail.com
SMTP_PASSWORD=nwtpimugzozbedrp
FROM_EMAIL=krasnovav932@gmail.com
EOF
    echo "   ✅ .env создан"
else
    echo "   ✅ .env уже существует"
fi

# ============================================================================
# 5. ОБНОВЛЕНИЕ .GITIGNORE
# ============================================================================
echo ""
echo "5. Обновление .gitignore..."

for pattern in ".env" "server/email_config.h" "*.pyc"; do
    if ! grep -q "$pattern" .gitignore 2>/dev/null; then
        echo "$pattern" >> .gitignore
    fi
done

echo "   ✅ .gitignore обновлен"

# ============================================================================
# 6. ПЕРЕСБОРКА DOCKER ОБРАЗА
# ============================================================================
echo ""
echo "6. Пересборка Docker образа..."

docker-compose down 2>/dev/null
docker-compose build --no-cache server 2>/dev/null
docker-compose up -d 2>/dev/null

echo "   ✅ Docker образ пересобран и запущен"

# ============================================================================
# 7. ПРОВЕРКА
# ============================================================================
echo ""
echo "7. Проверка..."

sleep 3

# Проверка, что send_email.py скопировался
if docker exec function_plotter_server ls -la /root/server/send_email.py 2>/dev/null; then
    echo "   ✅ send_email.py скопирован в контейнер"
else
    echo "   ❌ send_email.py НЕ скопирован в контейнер"
    echo "   Пробуем скопировать вручную..."
    docker cp server/send_email.py function_plotter_server:/root/server/
    echo "   ✅ send_email.py скопирован вручную"
fi

# Проверка, что Python скрипт работает
echo "   Проверка Python скрипта..."
docker exec function_plotter_server python3 /root/server/send_email.py "test@example.com" "Test" "Test" 2>&1 || echo "   ⚠️ Python скрипт не работает, но это нормально (нет SMTP)"

# Проверка переменных окружения
echo "   Переменные SMTP в контейнере:"
docker exec function_plotter_server env | grep SMTP || echo "   ⚠️ Переменные SMTP не найдены"

# ============================================================================
# 8. ЛОГИ
# ============================================================================
echo ""
echo "8. Логи сервера (последние 10 строк):"
docker-compose logs server --tail 10

# ============================================================================
# 9. ИТОГ
# ============================================================================
echo ""
echo "=========================================="
echo "  ГОТОВО!"
echo "=========================================="
echo ""
echo "✅ Что сделано:"
echo "   - Dockerfile обновлен (добавлен Python и send_email.py)"
echo "   - send_email.py создан на хосте"
echo "   - Функция sendEmail в сервере обновлена"
echo "   - .env файл настроен"
echo "   - Docker пересобран и запущен"
echo ""
echo "📧 Проверьте .env файл (укажите свои SMTP данные):"
echo "   nano ~/projects/function-plotter-copy/timp-project/.env"
echo ""
echo "🚀 Проверить логи:"
echo "   docker-compose logs -f server"
echo ""
echo "🔑 Код для восстановления выводится в консоль сервера"
echo "=========================================="
EOF

chmod +x fix_email_final.sh
./fix_email_final.sh
