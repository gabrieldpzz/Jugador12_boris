# app.py
# Server: RAG (Ollama + pgvector + LM Studio) + Auth (register/login/OTP/JWT)

import os
import base64
import time
import smtplib
from email.message import EmailMessage
from typing import List, Optional

import psycopg2
from psycopg2.extensions import register_adapter, AsIs
from pgvector.psycopg2 import register_vector
import requests
import json
import numpy as np

import bcrypt
import jwt

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr

# ----------------- CONFIG -----------------
POSTGRES_CONFIG = {
    'user': 'jugador_user',
    'password': 'micontrasenasegura123',
    'host': '192.168.1.5',   # IP PC con Postgres
    'port': 5432,
    'database': 'jugador_db'
}

# RAG endpoints (como ya los tenías)
OLLAMA_EMBED_URL      = "http://192.168.1.5:11434/api/embeddings"
OLLAMA_EMBED_MODEL    = "nomic-embed-text"
LM_STUDIO_CHAT_URL    = "http://192.168.56.1:1234/v1/chat/completions"
LM_STUDIO_CHAT_MODEL  = "phi-3.1-mini-4k-instruct"
EMBEDDING_DIMENSIONS  = 768

# Tabla / columnas RAG
TABLE_NAME            = "products"
COL_ID                = "id"
COL_NAME              = "name"
COL_TEAM              = "team"
COL_CATEGORY          = "category"
COL_PRICE             = "price"
COL_IMAGE_URL         = "image_url"
COL_DESCRIPTION       = "description"
COL_EMBEDDING         = "embedding"

# --- Auth / SMTP / JWT ---
SMTP_HOST     = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT     = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("SMTP_USERNAME", "g.alexis7112@gmail.com")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "cvmnxdzgiisrwwpp")
SMTP_FROM     = os.getenv("SMTP_FROM", SMTP_USERNAME)

JWT_SECRET    = os.getenv("JWT_SECRET", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KMUFsIDTnFmyG3nMiGM6H9FNFUROf3wh7SmqJp-QV30")
OTP_EXP_MIN   = int(os.getenv("OTP_EXP_MINUTES", "10"))

# ----------------- FASTAPI -----------------
app = FastAPI(title="RAG+Auth Server", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # endurecer en prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------- MODELOS -----------------
class ChatTurn(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatTurn]] = None

class ChatResponse(BaseModel):
    answer: str

class ReindexResponse(BaseModel):
    ok: bool
    updated: int
    valid_total: int

class RegisterReq(BaseModel):
    email: EmailStr
    password: str

class LoginReq(BaseModel):
    email: EmailStr
    password: str

class VerifyOtpReq(BaseModel):
    otp_token: str
    code: str

class AuthOk(BaseModel):
    ok: bool

class OtpTokenResp(BaseModel):
    otp_token: str

class JwtTokenResp(BaseModel):
    token: str

# ----------------- HELPERS DB/NUMPY -----------------
def registrar_adaptadores_numpy():
    def addapt_numpy_float32(numpy_float32): return AsIs(numpy_float32)
    def addapt_numpy_float64(numpy_float64): return AsIs(numpy_float64)
    register_adapter(np.float32, addapt_numpy_float32)
    register_adapter(np.float64, addapt_numpy_float64)
registrar_adaptadores_numpy()

def db_conn_cursor():
    conn = psycopg2.connect(**POSTGRES_CONFIG)
    register_vector(conn)
    cur = conn.cursor()
    return conn, cur

def ensure_pgvector_and_products(conn, cur):
    try:
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector;"); conn.commit()
    except Exception: conn.rollback()
    # ensure embedding column
    try:
        cur.execute(f"ALTER TABLE {TABLE_NAME} ADD COLUMN IF NOT EXISTS {COL_EMBEDDING} VECTOR({EMBEDDING_DIMENSIONS});")
        conn.commit()
    except Exception: conn.rollback()
    try:
        cur.execute(f"ALTER TABLE {TABLE_NAME} ALTER COLUMN {COL_EMBEDDING} TYPE VECTOR({EMBEDDING_DIMENSIONS});")
        conn.commit()
    except Exception: conn.rollback()

def ensure_auth_tables():
    conn, cur = None, None
    try:
        conn, cur = db_conn_cursor()
        # users
        cur.execute("""
        CREATE TABLE IF NOT EXISTS users(
          id SERIAL PRIMARY KEY,
          email TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          created_at TIMESTAMPTZ DEFAULT NOW()
        );
        """)
        # login_otps
        cur.execute("""
        CREATE TABLE IF NOT EXISTS login_otps(
          id SERIAL PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          code TEXT NOT NULL,
          expires_at TIMESTAMPTZ NOT NULL,
          used_at TIMESTAMPTZ
        );
        """)
        conn.commit()
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.on_event("startup")
def on_start():
    ensure_auth_tables()
    # opcional: asegurar vector/embedding
    try:
        conn, cur = db_conn_cursor()
        ensure_pgvector_and_products(conn, cur)
    finally:
        try:
            cur.close(); conn.close()
        except Exception:
            pass

# ----------------- RAG CORE -----------------
def generar_embedding_ollama(texto: str):
    try:
        r = requests.post(
            OLLAMA_EMBED_URL,
            json={"model": OLLAMA_EMBED_MODEL, "prompt": texto},
            headers={"Content-Type": "application/json"},
            timeout=60
        )
        r.raise_for_status()
        data = r.json()
        return data.get("embedding")
    except Exception:
        return None

def count_valid_embeddings(conn, cur) -> int:
    cur.execute(
        f"SELECT COUNT(*) FROM {TABLE_NAME} WHERE {COL_EMBEDDING} IS NOT NULL AND vector_dims({COL_EMBEDDING}) = %s",
        (EMBEDDING_DIMENSIONS,)
    )
    n = cur.fetchone()[0]
    conn.commit()
    return int(n)

def buscar_similares_db(query_embedding: List[float], top_n=5) -> List[str]:
    if not query_embedding:
        return []
    conn, cur = None, None
    out = []
    try:
        conn, cur = db_conn_cursor()
        emb_np = np.array(query_embedding, dtype=np.float32)
        cur.execute(f"""
            SELECT {COL_NAME}, {COL_DESCRIPTION}, {COL_PRICE}, {COL_TEAM}, {COL_CATEGORY}
            FROM {TABLE_NAME}
            WHERE {COL_EMBEDDING} IS NOT NULL
            ORDER BY {COL_EMBEDDING} <-> %s
            LIMIT %s
        """, (emb_np, top_n))
        for name, desc, price, team, cat in cur.fetchall():
            out.append(f"- {name or 'N/A'} | equipo: {team or 'N/A'} | cat: {cat or 'N/A'} | precio: {price if price is not None else 'N/A'} | desc: {desc or 'N/A'}")
        conn.commit()
    except Exception:
        if conn: conn.rollback()
    finally:
        if cur: cur.close()
        if conn: conn.close()
    return out

def llamar_lm_studio_chat(prompt: str) -> str:
    try:
        r = requests.post(
            LM_STUDIO_CHAT_URL,
            headers={"Content-Type": "application/json"},
            json={
                "model": LM_STUDIO_CHAT_MODEL,
                "messages": [
                    {"role": "system", "content":
                        "Eres un asesor experto en camisetas deportivas. "
                        "Responde en español basándote ÚNICAMENTE en el inventario del contexto. "
                        "Si no hay coincidencia exacta, sugiere opciones cercanas."
                    },
                    {"role": "user", "content": prompt}
                ],
                "temperature": 0.5,
                "stream": False
            },
            timeout=90
        )
        r.raise_for_status()
        data = r.json()
        if data.get("choices"):
            return (data["choices"][0]["message"]["content"] or "").strip()
        return "La IA no devolvió una respuesta válida."
    except requests.exceptions.RequestException as e:
        raise HTTPException(502, f"LM Studio no responde en {LM_STUDIO_CHAT_URL}: {e}")
    except json.JSONDecodeError:
        raise HTTPException(502, "Respuesta no JSON de LM Studio.")

# ----------------- AUTH HELPERS -----------------
def user_id_by_email(email: str) -> Optional[int]:
    conn, cur = None, None
    try:
        conn, cur = db_conn_cursor()
        cur.execute("SELECT id FROM users WHERE email=%s LIMIT 1", (email,))
        row = cur.fetchone()
        conn.commit()
        return int(row[0]) if row else None
    finally:
        if cur: cur.close()
        if conn: conn.close()

def verify_password(email: str, password: str) -> bool:
    conn, cur = None, None
    try:
        conn, cur = db_conn_cursor()
        cur.execute("SELECT password_hash FROM users WHERE email=%s LIMIT 1", (email,))
        row = cur.fetchone()
        if not row: return False
        hashed = row[0].encode("utf-8")
        ok = bcrypt.checkpw(password.encode("utf-8"), hashed)
        conn.commit()
        return ok
    finally:
        if cur: cur.close()
        if conn: conn.close()

def create_user(email: str, password: str) -> int:
    conn, cur = None, None
    try:
        conn, cur = db_conn_cursor()
        pw_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        cur.execute("INSERT INTO users(email, password_hash) VALUES(%s, %s) RETURNING id", (email, pw_hash))
        uid = cur.fetchone()[0]
        conn.commit()
        return int(uid)
    finally:
        if cur: cur.close()
        if conn: conn.close()

def gen_otp() -> str:
    import random
    return "".join(str(random.randint(0,9)) for _ in range(6))

def store_otp(user_id: int, code: str, minutes: int = OTP_EXP_MIN) -> None:
    conn, cur = None, None
    try:
        conn, cur = db_conn_cursor()
        cur.execute(
            "INSERT INTO login_otps(user_id, code, expires_at) VALUES(%s,%s, NOW() + INTERVAL '%s minute')",
            (user_id, code, minutes)
        )
        conn.commit()
    finally:
        if cur: cur.close()
        if conn: conn.close()

def consume_otp(user_id: int, code: str) -> bool:
    conn, cur = None, None
    try:
        conn, cur = db_conn_cursor()
        cur.execute("""
            SELECT id, expires_at, used_at
            FROM login_otps
            WHERE user_id=%s AND code=%s
            ORDER BY id DESC LIMIT 1
        """, (user_id, code))
        row = cur.fetchone()
        if not row: 
            conn.commit(); return False
        otp_id, expires_at, used_at = row
        if used_at is not None: 
            conn.commit(); return False
        cur.execute("SELECT NOW() > %s", (expires_at,))
        expired = cur.fetchone()[0]
        if expired:
            conn.commit(); return False
        cur.execute("UPDATE login_otps SET used_at=NOW() WHERE id=%s", (otp_id,))
        conn.commit()
        return True
    finally:
        if cur: cur.close()
        if conn: conn.close()

def send_otp_email(to_email: str, code: str):
    msg = EmailMessage()
    msg["Subject"] = "Tu código de verificación"
    msg["From"] = SMTP_FROM
    msg["To"] = to_email
    msg.set_content(f"Tu código es: {code} (válido por {OTP_EXP_MIN} minutos).")
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as smtp:
        smtp.starttls()
        smtp.login(SMTP_USERNAME, SMTP_PASSWORD)
        smtp.send_message(msg)

def issue_jwt(user_id: int) -> str:
    payload = {"uid": user_id, "iss": "rag_auth", "iat": int(time.time())}
    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
    return token

# ----------------- ENDPOINTS -----------------
@app.get("/health")
def health():
    return {"ok": True}

# ---- RAG ----
@app.post("/rag/reindex", response_model=ReindexResponse)
def reindex():
    updated_count = 0
    conn, cur = None, None
    try:
        conn, cur = db_conn_cursor()
        ensure_pgvector_and_products(conn, cur)
        cur.execute(f"""
            SELECT {COL_ID},
                   COALESCE({COL_DESCRIPTION}, '') || ' | ' ||
                   COALESCE({COL_NAME}, '')       || ' | ' ||
                   COALESCE({COL_TEAM}, '')       || ' | ' ||
                   COALESCE({COL_CATEGORY}, '')   || ' | ' ||
                   COALESCE({COL_PRICE}::text, '')
            FROM {TABLE_NAME}
            WHERE {COL_EMBEDDING} IS NULL
               OR vector_dims({COL_EMBEDDING}) != %s
        """, (EMBEDDING_DIMENSIONS,))
        for prod_id, texto in cur.fetchall():
            texto = (texto or "").strip()
            if not texto: 
                continue
            emb = generar_embedding_ollama(texto)
            if emb:
                emb_np = np.array(emb, dtype=np.float32)
                cur.execute(
                    f"UPDATE {TABLE_NAME} SET {COL_EMBEDDING} = %s WHERE {COL_ID} = %s",
                    (emb_np, prod_id)
                )
                conn.commit()
                updated_count += 1
        valid_total = count_valid_embeddings(conn, cur)
        return ReindexResponse(ok=True, updated=updated_count, valid_total=valid_total)
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(500, f"Error reindex: {e}")
    finally:
        if cur: cur.close()
        if conn: conn.close()

@app.post("/rag/chat", response_model=ChatResponse)
def rag_chat(req: ChatRequest):
    message = (req.message or "").strip()
    if not message:
        raise HTTPException(400, "message vacío")

    q_emb = generar_embedding_ollama(message)
    context_lines = buscar_similares_db(q_emb, top_n=5) if q_emb else []

    history_txt = ""
    if req.history:
        try:
            last_assistant = next((h.content for h in reversed(req.history) if h.role == "assistant"), "")
            if last_assistant:
                history_txt = f"\n\nÚltima respuesta del asistente: {last_assistant}"
        except Exception:
            pass

    if context_lines:
        prompt = (
            "Contexto de productos similares:\n"
            + "\n".join(context_lines)
            + "\n\nCon base principalmente en el contexto anterior, responde a: "
            + message
            + "\nSé conciso."
            + history_txt
        )
    else:
        prompt = f"Responde: {message}\nSé conciso."

    answer = llamar_lm_studio_chat(prompt)
    return ChatResponse(answer=answer)

# ---- AUTH ----
@app.post("/auth/register", response_model=AuthOk)
def auth_register(req: RegisterReq):
    email = req.email.lower().strip()
    if len(req.password) < 6:
        raise HTTPException(400, "password muy corta (min 6)")
    existing = user_id_by_email(email)
    if existing is not None:
        raise HTTPException(400, "email_in_use")
    uid = create_user(email, req.password)
    return AuthOk(ok=True)

@app.post("/auth/login", response_model=OtpTokenResp)
def auth_login(req: LoginReq):
    email = req.email.lower().strip()
    uid = user_id_by_email(email)
    if uid is None:
        raise HTTPException(401, "invalid_credentials")
    if not verify_password(email, req.password):
        raise HTTPException(401, "invalid_credentials")
    code = gen_otp()
    store_otp(uid, code, OTP_EXP_MIN)
    try:
        send_otp_email(email, code)
    except Exception as e:
        raise HTTPException(502, f"error_envio_email: {e}")
    otp_token = base64.urlsafe_b64encode(f"{uid}|{int(time.time())}".encode()).decode()
    return OtpTokenResp(otp_token=otp_token)

@app.post("/auth/verify-otp", response_model=JwtTokenResp)
def auth_verify_otp(req: VerifyOtpReq):
    try:
        decoded = base64.urlsafe_b64decode(req.otp_token.encode()).decode()
        uid_str, _ts = decoded.split("|", 1)
        uid = int(uid_str)
    except Exception:
        raise HTTPException(400, "invalid_otp_token")
    if not consume_otp(uid, req.code):
        raise HTTPException(401, "invalid_or_expired_code")
    token = issue_jwt(uid)
    return JwtTokenResp(token=token)

# ----------------- RUN -----------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001, reload=False)
