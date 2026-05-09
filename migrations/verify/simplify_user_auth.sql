-- Verify simplify_user_auth
-- 验证 admin 用户存在且约束已修改
SELECT id FROM users WHERE username = 'admin' AND admin = TRUE;

-- 验证 email 可以为 NULL
SELECT 1 WHERE NOT EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_name = 'users' AND column_name = 'email' AND is_nullable = 'NO'
);
