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
gunicorn --bind=0.0.0.0:8000 app.api:app 