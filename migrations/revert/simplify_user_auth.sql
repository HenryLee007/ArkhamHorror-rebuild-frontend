-- Revert simplify_user_auth
BEGIN;

-- 删除 admin 用户
DELETE FROM users WHERE username = 'admin';

-- 恢复 NOT NULL 约束
ALTER TABLE users ALTER COLUMN email SET NOT NULL;
ALTER TABLE users ALTER COLUMN password_digest SET NOT NULL;

COMMIT;
