import uvicorn
from api import app  # Asegúrate de que el nombre del archivo coincide con tu API

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
