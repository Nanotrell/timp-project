#!/bin/bash
echo "Установка Function Plotter..."

# Проверка Git
if ! command -v git &> /dev/null; then
    sudo apt-get install git -y
fi

# Клонирование
git clone https://github.com/Nanotrell/timp-project.git
cd timp-project

# Установка Qt
sudo apt-get install qt5-default qtbase5-dev -y

# Установка PostgreSQL
sudo apt-get install postgresql postgresql-contrib -y

# Настройка БД
sudo -u postgres psql -f server/update_database.sql

# Сборка
cd server && qmake && make && cd ..
cd client && qmake && make && cd ..

echo "Готово! Запустите сервер: cd server && ./server"
echo "И клиент: cd client && ./client"
