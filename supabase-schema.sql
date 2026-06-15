-- ============================================================
-- 垂类产品管理系统 - Supabase Schema Migration
-- ============================================================
-- 部署步骤：
-- 1. 创建 Supabase 项目 (https://supabase.com/dashboard)
-- 2. 进入 SQL Editor，依次执行以下 SQL
-- ============================================================

-- ===== 1. 创建 suppliers 表 =====
CREATE TABLE IF NOT EXISTS public.suppliers (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  contact TEXT NOT NULL,
  phone TEXT NOT NULL,
  province TEXT,
  city TEXT,
  category TEXT NOT NULL,
  business TEXT DEFAULT '',
  service TEXT DEFAULT '',
  rating TEXT DEFAULT 'B级' CHECK (rating IN ('S级','A级','B级','C级','D级')),
  status TEXT DEFAULT '合作中' CHECK (status IN ('合作中','已暂停')),
  payment TEXT DEFAULT '月结' CHECK (payment IN ('现结','月结','季结','半年结','年结','预付款')),
  return_policy TEXT DEFAULT '',
  shop_url TEXT DEFAULT '',
  order_url TEXT DEFAULT '',
  address TEXT DEFAULT '',
  founded DATE,
  employees TEXT DEFAULT '',
  annual TEXT DEFAULT '',
  qualification TEXT DEFAULT '',
  remark TEXT DEFAULT '',
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== 2. 创建 products 表 =====
CREATE TABLE IF NOT EXISTS public.products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  cat1 TEXT NOT NULL,
  cat2 TEXT DEFAULT '',
  cat3 TEXT DEFAULT '',
  supplier_id BIGINT REFERENCES public.suppliers(id) ON DELETE SET NULL,
  supplier_name TEXT DEFAULT '',
  platforms TEXT[] DEFAULT '{}',
  status TEXT DEFAULT '上架中' CHECK (status IN ('上架中','已下架')),
  order_url TEXT DEFAULT '',
  remark TEXT DEFAULT '',
  -- certs stored as JSONB: { "CE": { checked: true, date: "2024-01-15" }, ... }
  certs JSONB DEFAULT '{}',
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== 3. 创建 certification files 表 =====
CREATE TABLE IF NOT EXISTS public.product_cert_files (
  id BIGSERIAL PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  cert_name TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size BIGINT DEFAULT 0,
  storage_path TEXT NOT NULL,  -- Supabase Storage path: cert-files/{product_id}/{cert_name}/{file_name}
  mime_type TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(product_id, cert_name, file_name)
);

-- ===== 4. 创建 activity_log 表（实时动态） =====
CREATE TABLE IF NOT EXISTS public.activity_log (
  id BIGSERIAL PRIMARY KEY,
  action TEXT NOT NULL,        -- 'create_supplier', 'update_product', 'delete_supplier', etc.
  entity_type TEXT NOT NULL,   -- 'supplier', 'product'
  entity_id TEXT NOT NULL,
  entity_name TEXT DEFAULT '',
  detail JSONB DEFAULT '{}',
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===== 5. 创建 updated_at 触发器 =====
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS suppliers_updated_at ON public.suppliers;
CREATE TRIGGER suppliers_updated_at
  BEFORE UPDATE ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS products_updated_at ON public.products;
CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ===== 6. 创建 activity 自动记录触发器 =====
CREATE OR REPLACE FUNCTION public.log_activity()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.activity_log (action, entity_type, entity_id, entity_name, detail, created_by)
  VALUES (
    CASE
      WHEN TG_OP = 'INSERT' THEN 'create_' || TG_TABLE_NAME
      WHEN TG_OP = 'UPDATE' THEN 'update_' || TG_TABLE_NAME
      WHEN TG_OP = 'DELETE' THEN 'delete_' || TG_TABLE_NAME
    END,
    CASE
      WHEN TG_TABLE_NAME = 'suppliers' THEN 'supplier'
      WHEN TG_TABLE_NAME = 'products' THEN 'product'
      ELSE TG_TABLE_NAME
    END,
    CASE
      WHEN TG_TABLE_NAME = 'suppliers' THEN NEW.id::TEXT
      WHEN TG_TABLE_NAME = 'products' THEN NEW.id
    END,
    CASE
      WHEN TG_TABLE_NAME = 'suppliers' THEN NEW.name
      WHEN TG_TABLE_NAME = 'products' THEN NEW.name
    END,
    CASE
      WHEN TG_OP = 'DELETE' THEN '{}'
      WHEN TG_TABLE_NAME = 'suppliers' THEN
        json_build_object('name', NEW.name, 'status', NEW.status, 'rating', NEW.rating)
      WHEN TG_TABLE_NAME = 'products' THEN
        json_build_object('name', NEW.name, 'status', NEW.status, 'cat1', NEW.cat1)
    END,
    NEW.created_by
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS suppliers_activity ON public.suppliers;
CREATE TRIGGER suppliers_activity
  AFTER INSERT OR UPDATE OR DELETE ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION public.log_activity();

DROP TRIGGER IF EXISTS products_activity ON public.products;
CREATE TRIGGER products_activity
  AFTER INSERT OR UPDATE OR DELETE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.log_activity();

-- ===== 7. Row Level Security (RLS) =====
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_cert_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

-- 策略：所有认证用户可读写（协同模式）
-- 如需限制只看自己创建的数据，改为 WHERE created_by = auth.uid()

-- suppliers
CREATE POLICY "Suppliers: authenticated users can read" ON public.suppliers
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Suppliers: authenticated users can insert" ON public.suppliers
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Suppliers: authenticated users can update" ON public.suppliers
  FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Suppliers: authenticated users can delete" ON public.suppliers
  FOR DELETE USING (auth.role() = 'authenticated');

-- products
CREATE POLICY "Products: authenticated users can read" ON public.products
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Products: authenticated users can insert" ON public.products
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Products: authenticated users can update" ON public.products
  FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Products: authenticated users can delete" ON public.products
  FOR DELETE USING (auth.role() = 'authenticated');

-- product_cert_files
CREATE POLICY "CertFiles: authenticated users can read" ON public.product_cert_files
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "CertFiles: authenticated users can insert" ON public.product_cert_files
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "CertFiles: authenticated users can update" ON public.product_cert_files
  FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "CertFiles: authenticated users can delete" ON public.product_cert_files
  FOR DELETE USING (auth.role() = 'authenticated');

-- activity_log
CREATE POLICY "ActivityLog: authenticated users can read" ON public.activity_log
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "ActivityLog: authenticated users can insert" ON public.activity_log
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ===== 8. 创建 Supabase Storage Bucket =====
-- 在 Supabase Dashboard > Storage 中手动创建名为 'cert-files' 的 bucket
-- 或使用以下 SQL（需要 storage admin 权限）：
-- INSERT INTO storage.buckets (id, name, public) VALUES ('cert-files', 'cert-files', false);
-- 然后设置 storage 策略：
-- CREATE POLICY "CertStorage: authenticated users can upload" ON storage.objects
--   FOR INSERT WITH CHECK (bucket_id = 'cert-files' AND auth.role() = 'authenticated');
-- CREATE POLICY "CertStorage: authenticated users can read" ON storage.objects
--   FOR SELECT USING (bucket_id = 'cert-files' AND auth.role() = 'authenticated');
-- CREATE POLICY "CertStorage: authenticated users can delete" ON storage.objects
--   FOR DELETE USING (bucket_id = 'cert-files' AND auth.role() = 'authenticated');

-- ===== 9. 索引优化 =====
CREATE INDEX IF NOT EXISTS idx_suppliers_category ON public.suppliers(category);
CREATE INDEX IF NOT EXISTS idx_suppliers_status ON public.suppliers(status);
CREATE INDEX IF NOT EXISTS idx_suppliers_province ON public.suppliers(province);
CREATE INDEX IF NOT EXISTS idx_products_cat1 ON public.products(cat1);
CREATE INDEX IF NOT EXISTS idx_products_status ON public.products(status);
CREATE INDEX IF NOT EXISTS idx_products_supplier_id ON public.products(supplier_id);
CREATE INDEX IF NOT EXISTS idx_cert_files_product_cert ON public.product_cert_files(product_id, cert_name);
CREATE INDEX IF NOT EXISTS idx_activity_log_created_at ON public.activity_log(created_at DESC);
