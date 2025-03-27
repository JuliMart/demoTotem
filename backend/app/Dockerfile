# Imagen base con Python 3.11
FROM python:3.11

# Instalación de dependencias del sistema necesarias para OpenCV y Mediapipe
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Directorio de trabajo
WORKDIR /app

# Copia e instala dependencias Python
COPY requirements.txt /app/
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copia el código del backend
COPY backend/app ./backend/app

# Puerto expuesto
EXPOSE 8000

# Comando para iniciar FastAPI
CMD ["uvicorn", "backend.app.api:app", "--host", "0.0.0.0", "--port", "8000"]
