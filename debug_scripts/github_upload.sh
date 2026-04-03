#!/bin/bash
set -e

echo "=========================================="
echo "  ЗАГРУЗКА ПРОЕКТА В GITHUB"
echo "  Репозиторий: Nanotrell/timp-project"
echo "=========================================="

PROJECT_DIR=~/projects/function-plotter
cd "$PROJECT_DIR"

# Настройка .gitignore
cat > .gitignore << 'GITIGNORE'
*.pro.user
*.o
*.so
*.exe
moc_*.cpp
ui_*.h
build/
debug/
release/
__pycache__/
.vscode/
.idea/
docs/html/
docs/latex/
GITIGNORE

# Добавление всех файлов
git add .
git add server/*.cpp server/*.h server/*.pro server/Dockerfile 2>/dev/null
git add client/*.cpp client/*.h client/*.pro 2>/dev/null
git add tests/*.cpp tests/*.pro 2>/dev/null
git add wiki/*.md 2>/dev/null
git add Doxyfile docker-compose.yml .gitignore README.md 2>/dev/null

# Коммит
git commit -m "Initial commit: Function Plotter project

Features:
- TCP server on C++ with PostgreSQL
- Qt client with function graph
- 3 sliders for parameters a, b, c
- Table with 20 points
- Registration and authorization
- Password recovery with email code
- Docker containerization
- Unit tests for MathEngine"

# Добавление remote (если нет)
if ! git remote | grep -q "origin"; then
    git remote add origin https://github.com/Nanotrell/timp-project.git
fi

# Пуш
git push -u origin main

echo ""
echo "✅ Готово! Проект загружен: https://github.com/Nanotrell/timp-project"
