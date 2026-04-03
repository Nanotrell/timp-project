QT -= gui
QT += network sql

CONFIG += c++11 console
CONFIG -= app_bundle

DEFINES += QT_DEPRECATED_WARNINGS

SOURCES += \
    main.cpp \
    postgresqlserver.cpp \
    database.cpp \
    math_engine.cpp

HEADERS += \
    postgresqlserver.h \
    database.h \
    math_engine.h

# Добавляем auth.cpp
SOURCES += auth.cpp
HEADERS += auth.h
