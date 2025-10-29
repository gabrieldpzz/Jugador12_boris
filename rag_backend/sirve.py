# rag_vector_ollama_lmstudio.py
# RAG: Ollama Embeddings (nomic-embed-text) + pgvector + LM Studio Chat (phi-3.1-mini-4k-instruct)
# Tablas/credenciales adaptadas a: products(id, name, team, category, price, image_url, description)

import psycopg2
from psycopg2.extensions import register_adapter, AsIs
from pgvector.psycopg2 import register_vector
import requests
import json
import numpy as np

# ----------------- CONFIG -----------------
POSTGRES_CONFIG = {
    'user': 'jugador_user',
    'password': 'micontrasenasegura123',
    'host': '192.168.1.5',   # IP de tu PC (donde corre el contenedor de Postgres)
    'port': 5432,
    'database': 'jugador_db'
}

# Endpoints locales (cámbialos si LM/Ollama corren en otra IP/puerto)
OLLAMA_EMBED_URL      = "http://192.168.1.5:11434/api/embeddings"
OLLAMA_EMBED_MODEL    = "nomic-embed-text"           # Modelo de embeddings instalado en Ollama
LM_STUDIO_CHAT_URL    = "http://192.168.56.1:1234/v1/chat/completions"  # OpenAI server de LM Studio
LM_STUDIO_CHAT_MODEL  = "phi-3.1-mini-4k-instruct"

EMBEDDING_DIMENSIONS  = 768  # nomic-embed-text

# Tabla / columnas esperadas
TABLE_NAME            = "products"
COL_ID                = "id"
COL_NAME              = "name"
COL_TEAM              = "team"
COL_CATEGORY          = "category"
COL_PRICE             = "price"
COL_IMAGE_URL         = "image_url"
COL_DESCRIPTION       = "description"
COL_EMBEDDING         = "embedding"   # nueva/ajustada por este script

# ------------------------------------------

def registrar_adaptadores_numpy():
    """Permite a psycopg2 manejar np.float32/64 al pasar vectores a pgvector."""
    def addapt_numpy_float32(numpy_float32): return AsIs(numpy_float32)
    def addapt_numpy_float64(numpy_float64): return AsIs(numpy_float64)
    register_adapter(np.float32, addapt_numpy_float32)
    register_adapter(np.float64, addapt_numpy_float64)

def generar_embedding_ollama(texto: str) -> list[float] | None:
    """Genera embedding con Ollama."""
    try:
        resp = requests.post(
            OLLAMA_EMBED_URL,
            json={"model": OLLAMA_EMBED_MODEL, "prompt": texto},
            headers={"Content-Type": "application/json"},
            timeout=60
        )
        resp.raise_for_status()
        data = resp.json()
        if "embedding" in data:
            return data["embedding"]
        print(f"[Ollama] Respuesta inválida: {data}")
        return None
    except requests.exceptions.RequestException as e:
        print(f"[Ollama] Error de conexión ({OLLAMA_EMBED_URL}): {e}")
        return None
    except json.JSONDecodeError:
        print(f"[Ollama] Respuesta no JSON: {resp.text if 'resp' in locals() else ''}")
        return None

def asegurar_extensiones_y_columnas(conn, cursor):
    """Crea extensión pgvector y agrega/ajusta la columna embedding a VECTOR(768)."""
    # 1) Crear extensión pgvector
    try:
        cursor.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        conn.commit()
        print("[DB] EXTENSION 'vector' OK.")
    except Exception as e:
        print(f"[DB] Aviso al crear EXTENSION vector: {e}")
        conn.rollback()

    # 2) Agregar columna si no existe
    try:
        cursor.execute(f"ALTER TABLE {TABLE_NAME} ADD COLUMN IF NOT EXISTS {COL_EMBEDDING} VECTOR({EMBEDDING_DIMENSIONS});")
        conn.commit()
        print(f"[DB] Columna '{COL_EMBEDDING}' creada/verificada.")
    except Exception as e:
        print(f"[DB] Aviso al agregar columna '{COL_EMBEDDING}': {e}")
        conn.rollback()

    # 3) Asegurar dimensión correcta de la columna
    try:
        cursor.execute(f"ALTER TABLE {TABLE_NAME} ALTER COLUMN {COL_EMBEDDING} TYPE VECTOR({EMBEDDING_DIMENSIONS});")
        conn.commit()
        print(f"[DB] Columna '{COL_EMBEDDING}' ajustada a VECTOR({EMBEDDING_DIMENSIONS}).")
    except Exception as e:
        print(f"[DB] Aviso al ajustar tipo de '{COL_EMBEDDING}': {e}")
        conn.rollback()

def indexar_datos_db():
    """Genera y guarda embeddings para productos sin embedding o con dimensión incorrecta."""
    conn = None
    cursor = None
    print("\n[Indexación] Verificando/generando embeddings en PostgreSQL...")
    updated_count = 0
    try:
        conn = psycopg2.connect(**POSTGRES_CONFIG)
        register_vector(conn)
        registrar_adaptadores_numpy()
        cursor = conn.cursor()

        asegurar_extensiones_y_columnas(conn, cursor)

        # Seleccionar filas sin embedding o con dimensión incorrecta
        cursor.execute(f"""
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
        pendientes = cursor.fetchall()

        if not pendientes:
            print("[Indexación] Todos los productos ya tienen embeddings válidos.")
            return

        print(f"[Indexación] {len(pendientes)} productos necesitan embedding. Generando...")
        for prod_id, texto in pendientes:
            texto = (texto or "").strip()
            if not texto:
                print(f"[Indexación] ID {prod_id}: texto vacío, omitiendo.")
                continue

            emb = generar_embedding_ollama(texto)
            if emb:
                emb_np = np.array(emb, dtype=np.float32)
                cursor.execute(
                    f"UPDATE {TABLE_NAME} SET {COL_EMBEDDING} = %s WHERE {COL_ID} = %s",
                    (emb_np, prod_id)
                )
                conn.commit()
                updated_count += 1
                print(f"[Indexación] ID {prod_id}: embedding guardado.")
            else:
                print(f"[Indexación] ID {prod_id}: falló generación de embedding.")

        print(f"[Indexación] Completado. Embeddings creados/actualizados: {updated_count}.")

    except (Exception, psycopg2.Error) as e:
        print(f"[Indexación] Error PostgreSQL: {e}")
        if "vector_dims" in str(e):
            print("HINT: Verifica que 'pgvector' esté instalada y activa (CREATE EXTENSION vector;).")
        if conn: conn.rollback()
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

def buscar_similares_db(query_embedding: list[float], top_n=3) -> list[str]:
    """Devuelve las N líneas de texto de productos más similares (para contexto)."""
    resultados_texto = []
    if not query_embedding:
        return resultados_texto

    conn = None
    cursor = None
    try:
        conn = psycopg2.connect(**POSTGRES_CONFIG)
        register_vector(conn)
        registrar_adaptadores_numpy()
        cursor = conn.cursor()

        query_embedding_np = np.array(query_embedding, dtype=np.float32)

        sql = f"""
            SELECT {COL_NAME}, {COL_DESCRIPTION}, {COL_PRICE}, {COL_TEAM}, {COL_CATEGORY}
            FROM {TABLE_NAME}
            WHERE {COL_EMBEDDING} IS NOT NULL
            ORDER BY {COL_EMBEDDING} <-> %s
            LIMIT %s
        """
        cursor.execute(sql, (query_embedding_np, top_n))
        rows = cursor.fetchall()

        if rows:
            print(f"\n[Vector-DB] {len(rows)} similares:")
            for name, description, price, team, category in rows:
                name = name or "N/A"
                description = description or "N/A"
                price = price if price is not None else "N/A"
                team = team or "N/A"
                category = category or "N/A"
                line = f"- {name} | equipo: {team} | cat: {category} | precio: {price} | desc: {description}"
                print(line)
                resultados_texto.append(line)
        else:
            print("\n[Vector-DB] Sin resultados similares.")

    except (Exception, psycopg2.Error) as e:
        print(f"[Búsqueda] Error PostgreSQL: {e}")
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

    return resultados_texto

def llamar_lm_studio_chat(prompt_completo: str) -> str:
    """Llama al servidor OpenAI-compatible de LM Studio."""
    headers = {"Content-Type": "application/json"}
    payload = {
        "model": LM_STUDIO_CHAT_MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Eres un asesor experto en camisetas deportivas. "
                    "Responde en español basándote ÚNICAMENTE en el inventario del contexto. "
                    "Si no hay coincidencia exacta, sugiere opciones cercanas."
                )
            },
            {"role": "user", "content": prompt_completo}
        ],
        "temperature": 0.5,
        "stream": False
    }
    try:
        r = requests.post(LM_STUDIO_CHAT_URL, headers=headers, json=payload, timeout=90)
        r.raise_for_status()
        data = r.json()
        if data.get("choices"):
            return (data["choices"][0]["message"]["content"] or "").strip()
        return "La IA no devolvió una respuesta válida."
    except requests.exceptions.RequestException as e:
        return f"Error: No se pudo conectar a LM Studio en {LM_STUDIO_CHAT_URL} ({e})."
    except json.JSONDecodeError:
        return f"Error: Respuesta no JSON de LM Studio."

# ----------------- MAIN (REPL) -----------------
if __name__ == "__main__":
    print("--- RAG (Ollama + pgvector + LM Studio) — products ---")
    registrar_adaptadores_numpy()

    # 1) Indexar (crear embeddings faltantes)
    indexar_datos_db()

    # 2) REPL simple
    while True:
        q = input("\nPregunta (o 'salir'): ").strip()
        if q.lower() == "salir":
            break

        print("→ Generando embedding de la pregunta en Ollama…")
        q_emb = generar_embedding_ollama(q)
        if not q_emb:
            print("No se pudo generar embedding. Continuando sin búsqueda…")
            contexto = []
        else:
            contexto = buscar_similares_db(q_emb, top_n=3)

        if contexto:
            prompt = (
                "Contexto de productos similares:\n"
                + "\n".join(contexto)
                + "\n\nCon base principalmente en el contexto anterior, responde a: "
                + q
                + "\nSé conciso."
            )
        else:
            prompt = f"Responde: {q} (si no hay contexto, indica alternativas generales coherentes)."

        print("\n[Respuesta del modelo]:")
        print(llamar_lm_studio_chat(prompt))

    print("\n¡Listo!")
