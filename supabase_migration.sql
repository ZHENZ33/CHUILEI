-- ============================================================
-- 垂类产品管理系统 - Supabase 数据库迁移脚本
-- 请在 Supabase Dashboard → SQL Editor 中执行此脚本
-- ============================================================

-- 1. 启用 pgcrypto 扩展（用于密码哈希）
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. 用户表
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username    TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  display_name TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 3. 供应商表
CREATE TABLE IF NOT EXISTS suppliers (
  id            SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  contact       TEXT NOT NULL DEFAULT '',
  phone         TEXT NOT NULL DEFAULT '',
  province      TEXT DEFAULT '',
  city          TEXT DEFAULT '',
  category      TEXT DEFAULT '',
  business      TEXT DEFAULT '',
  service       TEXT DEFAULT '',
  rating        TEXT DEFAULT 'C级',
  status        TEXT DEFAULT '合作中',
  payment       TEXT DEFAULT '',
  return_policy TEXT DEFAULT '',
  shop_url      TEXT DEFAULT '',
  order_url     TEXT DEFAULT '',
  address       TEXT DEFAULT '',
  founded       TEXT DEFAULT '',
  employees     TEXT DEFAULT '',
  annual        TEXT DEFAULT '',
  qualification TEXT DEFAULT '',
  remark        TEXT DEFAULT '',
  created_by    UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- 4. 产品表
CREATE TABLE IF NOT EXISTS products (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL DEFAULT '',
  cat1          TEXT DEFAULT '',
  cat2          TEXT DEFAULT '',
  cat3          TEXT DEFAULT '',
  supplier_id   INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
  supplier_name TEXT DEFAULT '',
  platforms     TEXT[] DEFAULT '{}',
  certs         JSONB DEFAULT '{}',
  status        TEXT DEFAULT '上架中',
  order_url     TEXT DEFAULT '',
  remark        TEXT DEFAULT '',
  created_by    UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- 5. 资质文件表
CREATE TABLE IF NOT EXISTS cert_files (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id   TEXT REFERENCES products(id) ON DELETE CASCADE,
  cert_name    TEXT NOT NULL,
  file_name    TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  uploaded_by  UUID REFERENCES users(id),
  uploaded_at  TIMESTAMPTZ DEFAULT now()
);

-- 6. 认证 RPC 函数
CREATE OR REPLACE FUNCTION authenticate_user(p_username TEXT, p_password TEXT)
RETURNS TABLE(id UUID, username TEXT, role TEXT, display_name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.username, u.role, u.display_name
  FROM users u
  WHERE u.username = p_username
    AND u.password_hash = crypt(p_password, u.password_hash);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. 生成新产品编号 RPC 函数
CREATE OR REPLACE FUNCTION next_product_id()
RETURNS TEXT AS $$
DECLARE
  max_id TEXT;
  next_num INTEGER;
BEGIN
  SELECT id INTO max_id FROM products ORDER BY id DESC LIMIT 1;
  IF max_id IS NULL THEN
    RETURN 'P00001';
  END IF;
  next_num := substring(max_id, 2)::INTEGER + 1;
  RETURN 'P' || LPAD(next_num::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- 8. RLS 策略：允许已验证用户操作业务表
-- 注：简化方案，不做行级权限控制，所有已登录用户共享数据

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE cert_files ENABLE ROW LEVEL SECURITY;

-- 允许通过 RPC 验证的用户操作（使用 auth.uid() 检查）
-- 简化：使用 app.authenticated 声明

-- 实际上对于自定义认证，我们不需要 auth.uid()
-- 这里使用宽松策略：允许所有请求（通过 anon key 访问）
-- 安全由业务层登录控制

DROP POLICY IF EXISTS "Allow all for suppliers" ON suppliers;
CREATE POLICY "Allow all for suppliers" ON suppliers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for products" ON products;
CREATE POLICY "Allow all for products" ON products FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for cert_files" ON cert_files;
CREATE POLICY "Allow all for cert_files" ON cert_files FOR ALL USING (true) WITH CHECK (true);

-- 9. 创建默认管理员账号（密码: 123456）
INSERT INTO users (username, password_hash, role, display_name)
VALUES ('admin', crypt('123456', gen_salt('bf')), 'admin', '管理员')
ON CONFLICT (username) DO NOTHING;
