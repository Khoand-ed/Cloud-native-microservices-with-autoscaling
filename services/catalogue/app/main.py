import hashlib
import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool
from pydantic import BaseModel, Field

SERVICE = "catalogue"

DB_DSN = (
    f"host={os.getenv('DB_HOST', 'localhost')} "
    f"port={os.getenv('DB_PORT', '5432')} "
    f"dbname={os.getenv('DB_NAME', 'catalogue')} "
    f"user={os.getenv('DB_USER', 'catalogue')} "
    f"password={os.getenv('DB_PASSWORD', '')} "
    "connect_timeout=3"
)

pool = ConnectionPool(
    DB_DSN,
    min_size=int(os.getenv("DB_POOL_MIN", "1")),
    max_size=int(os.getenv("DB_POOL_MAX", "10")),
    kwargs={"row_factory": dict_row},
    open=False,
)

REQUESTS = Counter(
    "http_requests_total", "Total HTTP requests", ["component", "method", "path", "status"]
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["component", "method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5),
)

COLUMNS = "id, sku, name, category, price::float8 AS price, stock"


@asynccontextmanager
async def lifespan(_: FastAPI):
    pool.open(wait=False)
    yield
    pool.close()


app = FastAPI(title="Catalogue Service", lifespan=lifespan)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    route = request.scope.get("route")
    path = route.path if route else "unmatched"
    if path != "/metrics":
        LATENCY.labels(SERVICE, request.method, path).observe(time.perf_counter() - start)
        REQUESTS.labels(SERVICE, request.method, path, response.status_code).inc()
    return response


class ProductIn(BaseModel):
    sku: str = Field(min_length=1, max_length=32)
    name: str = Field(min_length=1, max_length=120)
    category: str = Field(min_length=1, max_length=60)
    price: float = Field(ge=0)
    stock: int = Field(default=0, ge=0)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    try:
        with pool.connection(timeout=2) as conn:
            conn.execute("SELECT 1")
    except Exception as exc:
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return {"status": "ready"}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/products")
def list_products(
    category: str | None = None,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    with pool.connection() as conn:
        if category:
            rows = conn.execute(
                f"SELECT {COLUMNS} FROM products WHERE category = %s ORDER BY id LIMIT %s OFFSET %s",
                (category, limit, offset),
            ).fetchall()
        else:
            rows = conn.execute(
                f"SELECT {COLUMNS} FROM products ORDER BY id LIMIT %s OFFSET %s",
                (limit, offset),
            ).fetchall()
    return {"items": rows, "limit": limit, "offset": offset}


@app.get("/products/{product_id}")
def get_product(product_id: int):
    with pool.connection() as conn:
        row = conn.execute(
            f"SELECT {COLUMNS} FROM products WHERE id = %s", (product_id,)
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="product not found")
    return row


@app.post("/products", status_code=201)
def create_product(product: ProductIn):
    with pool.connection() as conn:
        try:
            row = conn.execute(
                f"INSERT INTO products (sku, name, category, price, stock) "
                f"VALUES (%s, %s, %s, %s, %s) RETURNING {COLUMNS}",
                (product.sku, product.name, product.category, product.price, product.stock),
            ).fetchone()
        except Exception as exc:
            if getattr(exc, "sqlstate", None) == "23505":
                raise HTTPException(status_code=409, detail="sku already exists") from exc
            raise
    return row


@app.get("/stress")
def stress(ms: int = Query(20, ge=1, le=500)):
    """Burn CPU for ~`ms` milliseconds so the HPA has a predictable signal to react to."""
    deadline = time.perf_counter() + ms / 1000
    digest = b"catalogue"
    rounds = 0
    while time.perf_counter() < deadline:
        for _ in range(200):
            digest = hashlib.sha256(digest).digest()
        rounds += 200
    return {"burned_ms": ms, "hash_rounds": rounds}
