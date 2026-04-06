# Function Plotter

## Требования
- Ubuntu/Debian (или WSL на Windows) или Docker Desktop for Windows: https://www.docker.com/products/docker-desktop/
- Qt 5.x
- PostgreSQL
- Docker (опционально)

## Быстрый старт

### 1. Клонирование( для Ubuntu)
- предварительно запустить скрипт setup.sh
- в терминале выполнить:
- git clone https://github.com/Nanotrell/timp-project.git
- cd timp-project

ИЛИ

### 2. Запуск через Docker (для Windows)
- Скачать Docker Desktop for Windows: https://www.docker.com/products/docker-desktop/
- Открыть Docker Desktop, пропустить регистрацию и установить WSL предложенной в Docker Desktop командой в терминале
- в терминале выполнить:
- git clone https://github.com/Nanotrell/timp-project
- cd timp-project
- docker-compose up -d
- Подключиться к базе данных через Docker (выполнить команду в терминале):
- docker exec -it function_plotter_postgres psql -U plotter_user -d function_plotter
- Приложение клиента запускается при скачивании архива release.rar, распакуйте архив и запустите файл client.exe, разрешите его запуск
- После завершения работы с проектом, остановите запущенные контейнеры: docker-compose down
  
## Загрузить обновления из репозитория
- cd timp-project
- git pull origin main

## Сделать коммит в ветку master
- git add .  # добавить все изменённые файлы
## или
- git add имя_файла.cpp   # добавить конкретный файл
- git commit -m "Краткое описание того, что сделано"
## Отправить изменения на GitHub
- git push origin main
