# Usamos una imagen base de Python (puedes elegir la versión que necesites)
FROM python:3.11

# Instala las librerías de sistema necesarias para compilar dlib y otras dependencias
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    g++ \
    libboost-all-dev \
    libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copia el archivo de requerimientos a /app y luego instala las dependencias de Python
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copia el resto del código del proyecto en el contenedor
COPY . /app

# Expone el puerto 8000 (el que usaremos para la aplicación)
EXPOSE 8000

# Comando de inicio: aquí indicamos cómo arrancar la aplicación
CMD ["python", "-m", "uvicorn", "backend.app.api:app", "--host", "0.0.0.0", "--port", "8000"]
