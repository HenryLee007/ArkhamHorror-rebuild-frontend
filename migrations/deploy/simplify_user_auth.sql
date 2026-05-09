-- Deploy simplify_user_auth
BEGIN;

-- 清空现有数据（级联删除关联的 players 记录）
TRUNCATE users CASCADE;

-- 放宽约束：email 和 password_digest 改为可选
ALTER TABLE users ALTER COLUMN email DROP NOT NULL;
ALTER TABLE users ALTER COLUMN password_digest DROP NOT NULL;

-- 插入默认管理员账号
INSERT INTO users (username, email, password_digest, beta, admin)
VALUES ('admin', NULL, '$2a$12$ufhz5rOKS4FUZnCx/IRJo.vu/LbUnqQ7GW/NOEo4cgYAoOhDDnU1O', FALSE, TRUE);

COMMIT;
