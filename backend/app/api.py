import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import cv2
import mediapipe as mp
import threading
import time
import uvicorn
import logging
import numpy as np

app = FastAPI()

# Habilitar CORS
app.add_middleware(
    CORSMiddleware,
    # Aquí puedes especificar dominios, ej. ["http://localhost:8080"]
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inicialización de MediaPipe para las manos (gestos)
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.7,
)

# Inicialización de MediaPipe para pose (para liberar recursos)
mp_pose = mp.solutions.pose
pose = mp_pose.Pose(
    static_image_mode=False,
    model_complexity=1,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# Variables globales para comunicar el estado de gestos y color
gesture_detected = "waiting"
clothing_color = "unknown"  # Se almacenará un valor hexadecimal

# Captura de video (asegúrate de tener conectada una cámara)
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    logging.error("No se pudo abrir la cámara. Verifica que esté conectada.")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def compute_dominant_color(image, k=3):
    """
    Utiliza k-means clustering para obtener el color dominante en la imagen.
    Retorna un string hexadecimal en formato '#rrggbb'.
    """
    pixels = image.reshape((-1, 3))
    pixels = np.float32(pixels)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0)
    ret, label, center = cv2.kmeans(
        pixels, k, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS
    )
    _, counts = np.unique(label, return_counts=True)
    dominant = center[np.argmax(counts)]
    dominant = [int(x) for x in dominant]
    # Convertir de BGR a RGB para formato hexadecimal.
    return '#{:02x}{:02x}{:02x}'.format(dominant[2], dominant[1], dominant[0])


def get_finger_states(hand_landmarks):
    """
    Retorna una lista de 5 elementos (0 o 1) que indica si cada dedo está extendido.
    Para el pulgar se compara la posición x y para los demás dedos, la posición y.
    """
    tips_ids = [
        mp_hands.HandLandmark.THUMB_TIP,
        mp_hands.HandLandmark.INDEX_FINGER_TIP,
        mp_hands.HandLandmark.MIDDLE_FINGER_TIP,
        mp_hands.HandLandmark.RING_FINGER_TIP,
        mp_hands.HandLandmark.PINKY_TIP
    ]
    fingers = []
    # Pulgar: se compara la posición x con el landmark dos posiciones antes (THUMB_IP)
    if hand_landmarks.landmark[tips_ids[0]].x < hand_landmarks.landmark[tips_ids[0] - 2].x:
        fingers.append(1)
    else:
        fingers.append(0)
    # Para los otros dedos: se compara la posición y de la punta con la del nodo PIP (2 posiciones antes)
    for i in range(1, 5):
        if hand_landmarks.landmark[tips_ids[i]].y < hand_landmarks.landmark[tips_ids[i] - 2].y:
            fingers.append(1)
        else:
            fingers.append(0)
    return fingers


def recognize_number_gesture(fingers, hand_landmarks):
    """
    Interpreta el gesto basándose en el estado de los dedos.
    Retorna:
      - "thumbs_up" si el pulgar está elevado en comparación al índice.
      - "left_hand" o "right_hand" si se detecta movimiento de mano.
      - "waiting" en otros casos.
    """
    thumb_tip = hand_landmarks.landmark[mp_hands.HandLandmark.THUMB_TIP]
    index_tip = hand_landmarks.landmark[mp_hands.HandLandmark.INDEX_FINGER_TIP]

    # Si se detecta que el pulgar está arriba, se interpreta como thumbs_up
    if thumb_tip.y < index_tip.y:
        return "thumbs_up"

    # Identifica si es mano izquierda o derecha
    # Nota: Esto requiere contexto de MediaPipe para saber cuál mano es.
    # Para mantener tu estructura, devolveremos "hand" genérico.
    return "hand_detected"


def process_frames():
    global gesture_detected, clothing_color
    while True:
        try:
            ret, frame = cap.read()
            if not ret:
                gesture_detected = "waiting"
                clothing_color = "unknown"
                time.sleep(0.05)
                continue

            # Convertir la imagen a RGB para MediaPipe
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            result_hands = hands.process(rgb_frame)
            new_gesture = "waiting"

            if result_hands.multi_hand_landmarks and result_hands.multi_handedness:
                for idx, hand_landmarks in enumerate(result_hands.multi_hand_landmarks):
                    fingers = get_finger_states(hand_landmarks)

                    # Detectar thumbs_up
                    thumb_tip = hand_landmarks.landmark[mp_hands.HandLandmark.THUMB_TIP]
                    index_tip = hand_landmarks.landmark[mp_hands.HandLandmark.INDEX_FINGER_TIP]
                    if thumb_tip.y < index_tip.y:
                        new_gesture = "thumbs_up"
                        break

                    # Detectar izquierda o derecha
                    handedness = result_hands.multi_handedness[idx].classification[0].label
                    new_gesture = "left_hand" if handedness == "Left" else "right_hand"
                    break

            gesture_detected = new_gesture

            # Detección de color (sin cambios)
            h, w, _ = frame.shape
            roi_width = int(w * 0.3)
            roi_height = int(h * 0.3)
            center_x = w // 2
            center_y = h // 2
            x1 = max(center_x - roi_width // 2, 0)
            y1 = max(center_y - roi_height // 2, 0)
            x2 = min(center_x + roi_width // 2, w)
            y2 = min(center_y + roi_height // 2, h)
            roi = frame[y1:y2, x1:x2]
            if roi.size != 0:
                try:
                    dominant_color = compute_dominant_color(roi, k=3)
                    clothing_color = dominant_color
                except Exception as e:
                    logger.error(f"Error computing dominant color: {e}")
                    clothing_color = "error"

            time.sleep(0.05)

        except Exception as e:
            logger.error(f"Error en process_frames: {e}")
            time.sleep(1)


@app.websocket("/detect-gesture")
async def websocket_gesture(websocket: WebSocket):
    await websocket.accept()
    prev_gesture = None
    try:
        while True:
            if gesture_detected != prev_gesture:
                prev_gesture = gesture_detected
                await websocket.send_text(gesture_detected)
            await asyncio.sleep(0.2)
    except WebSocketDisconnect:
        logger.info("Gesture WebSocket disconnected")
    except Exception as e:
        logger.error(f"Error in gesture WebSocket: {e}")


@app.websocket("/detect-clothing")
async def websocket_clothing(websocket: WebSocket):
    await websocket.accept()
    prev_color = None
    try:
        while True:
            if clothing_color != prev_color:
                prev_color = clothing_color
                await websocket.send_text(clothing_color)
            await asyncio.sleep(0.5)
    except WebSocketDisconnect:
        logger.info("Clothing WebSocket disconnected")
    except Exception as e:
        logger.error(f"Error in clothing WebSocket: {e}")


@app.get("/")
async def home():
    return {"message": "FastAPI server is running"}


@app.on_event("startup")
def startup_event():
    threading.Thread(target=process_frames, daemon=True).start()
    logger.info("Frame processing thread started")


@app.on_event("shutdown")
def shutdown_event():
    cap.release()
    hands.close()
    pose.close()
    logger.info("Resources released")


if __name__ == "__main__":
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=True)
