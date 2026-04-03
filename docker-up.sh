#!/bin/bash
cd ~/projects/function-plotter
docker-compose up -d
echo "✅ Контейнеры запущены"
echo "Проверить: docker-compose ps"
echo "Логи: docker-compose logs -f server"
