#!/bin/bash
echo "Current directory: $(pwd)"
echo "Listing directory contents:"
ls -la

# Crear y activar entorno virtual
python -m venv antenv
source antenv/bin/activate

# Instalar dependencias
pip install --upgrade pip
pip install -r requirements.txt

# Iniciar la aplicación
python -m uvicorn backend.app.api:app --host 0.0.0.0 --port ${PORT:-8000}
