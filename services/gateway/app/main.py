import os
import time
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException, Query, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

SERVICE = "gateway"
CATALOGUE_URL = os.getenv("CATALOGUE_URL", "http://localhost:8001").rstrip("/")
UPSTREAM_TIMEOUT = float(os.getenv("UPSTREAM_TIMEOUT", "5"))

REQUESTS = Counter(
    "http_requests_total", "Total HTTP requests", ["service", "method", "path", "status"]
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["service", "method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5),
)

client: httpx.AsyncClient


@asynccontextmanager
async def lifespan(_: FastAPI):
    global client
    client = httpx.AsyncClient(
        base_url=CATALOGUE_URL,
        timeout=UPSTREAM_TIMEOUT,
        limits=httpx.Limits(max_connections=100, max_keepalive_connections=20),
    )
    yield
    await client.aclose()


app = FastAPI(title="API Gateway", lifespan=lifespan)


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


async def forward(method: str, path: str, **kwargs) -> Response:
    try:
        upstream = await client.request(method, path, **kwargs)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="catalogue service unreachable") from exc
    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        media_type=upstream.headers.get("content-type", "application/json"),
    )


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


@app.get("/readyz")
async def readyz():
    try:
        upstream = await client.get("/readyz", timeout=2)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="catalogue unavailable") from exc
    if upstream.status_code != 200:
        raise HTTPException(status_code=503, detail="catalogue not ready")
    return {"status": "ready"}


@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/products")
async def list_products(
    category: str | None = None,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    params = {"limit": limit, "offset": offset}
    if category:
        params["category"] = category
    return await forward("GET", "/products", params=params)


@app.get("/api/products/{product_id}")
async def get_product(product_id: int):
    return await forward("GET", f"/products/{product_id}")


@app.post("/api/products")
async def create_product(request: Request):
    return await forward("POST", "/products", content=await request.body(),
                         headers={"content-type": "application/json"})


@app.get("/api/stress")
async def stress(ms: int = Query(20, ge=1, le=500)):
    """Forwarded to the catalogue service, where the CPU work (and therefore the scaling) happens."""
    return await forward("GET", "/stress", params={"ms": ms})
