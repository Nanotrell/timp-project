#!/bin/bash
cd /home/oem123/timp-project/tests

# Пути к Qt
QT_PATH=/usr/include/x86_64-linux-gnu/qt5
QT_CORE=$QT_PATH/QtCore
QT_TEST=$QT_PATH/QtTest

# Флаги компиляции
FLAGS="-std=c++11 -fPIC -I../server -I$QT_PATH -I$QT_CORE -I$QT_TEST"
LIBS="-lQt5Test -lQt5Core"

# Генерация moc
/usr/lib/qt5/bin/moc test_math_engine.cpp -o test_math_engine.moc
/usr/lib/qt5/bin/moc test_auth.cpp -o test_auth.moc

# Компиляция test_math_engine
g++ $FLAGS -c test_math_engine.cpp -o test_math_engine.o
g++ $FLAGS -c ../server/math_engine.cpp -o math_engine.o
g++ $FLAGS -c ../server/auth.cpp -o auth.o
g++ -o test_math_engine test_math_engine.o math_engine.o auth.o $LIBS

# Компиляция test_auth
g++ $FLAGS -c test_auth.cpp -o test_auth.o
g++ -o test_auth test_auth.o math_engine.o auth.o $LIBS

# Запуск
echo "=== MATH ENGINE ==="
./test_math_engine
echo ""
echo "=== AUTH ==="
./test_auth
