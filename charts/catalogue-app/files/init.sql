CREATE TABLE IF NOT EXISTS products (
    id         SERIAL PRIMARY KEY,
    sku        VARCHAR(32)  NOT NULL UNIQUE,
    name       VARCHAR(120) NOT NULL,
    category   VARCHAR(60)  NOT NULL,
    price      NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    stock      INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products (category);

-- 100 sample products across 5 categories (idempotent)
INSERT INTO products (sku, name, category, price, stock)
SELECT
    'SKU-' || lpad(g::text, 4, '0'),
    (ARRAY['Laptop','Phone','Headset','Keyboard','Monitor'])[(g % 5) + 1] || ' Model ' || g,
    (ARRAY['computers','mobile','audio','accessories','displays'])[(g % 5) + 1],
    round((10 + (g * 7.31) % 990)::numeric, 2),
    (g * 13) % 200
FROM generate_series(1, 100) AS g
ON CONFLICT (sku) DO NOTHING;
