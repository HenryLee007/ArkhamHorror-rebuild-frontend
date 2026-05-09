<script setup lang="ts">
import { ref } from 'vue'
import AdminUI from '@/arkham/components/Admin/UI.vue'
import { fetchAdminUsers, createAdminUser, deleteAdminUser } from '@/api'
import type { AdminUser } from '@/api'

const users = ref<AdminUser[]>([])
const newUsername = ref('')
const loading = ref(false)
const error = ref('')
const confirmingUser = ref<AdminUser | null>(null)

async function loadUsers() {
  loading.value = true
  try {
    const res = await fetchAdminUsers()
    users.value = res.data
  } catch {
    error.value = '加载用户列表失败'
  } finally {
    loading.value = false
  }
}

async function handleCreate() {
  const username = newUsername.value.trim()
  if (!username) return
  error.value = ''
  try {
    await createAdminUser(username)
    newUsername.value = ''
    await loadUsers()
  } catch {
    error.value = '创建用户失败'
  }
}

function confirmDelete(user: AdminUser) {
  confirmingUser.value = user
}

async function handleDelete() {
  if (!confirmingUser.value) return
  error.value = ''
  try {
    await deleteAdminUser(confirmingUser.value.id)
    confirmingUser.value = null
    await loadUsers()
  } catch {
    error.value = '删除用户失败'
  }
}

function cancelDelete() {
  confirmingUser.value = null
}

loadUsers()
</script>

<template>
  <AdminUI :selected="'users'">
    <header class="topbar">
      <h1>账号管理</h1>
    </header>

    <section class="block">
      <!-- 新增用户 -->
      <div class="add-user">
        <input
          v-model="newUsername"
          class="input"
          placeholder="输入用户名"
          @keyup.enter="handleCreate"
        />
        <button class="btn btn-primary" @click="handleCreate">新增用户</button>
      </div>

      <p v-if="error" class="error-msg">{{ error }}</p>

      <!-- 用户列表 -->
      <div v-if="loading" class="empty">加载中...</div>
      <table v-else class="user-table">
        <thead>
          <tr>
            <th>用户名</th>
            <th>角色</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in users" :key="user.id">
            <td>{{ user.username }}</td>
            <td>{{ user.admin ? '管理员' : '普通用户' }}</td>
            <td>
              <button v-if="!user.admin" class="btn btn-danger" @click="confirmDelete(user)">删除</button>
            </td>
          </tr>
        </tbody>
      </table>

      <!-- 删除确认 -->
      <div v-if="confirmingUser" class="confirm-overlay" @click.self="cancelDelete">
        <div class="confirm-dialog">
          <p>确定删除用户 <strong>{{ confirmingUser.username }}</strong> 吗？</p>
          <div class="confirm-actions">
            <button class="btn btn-danger" @click="handleDelete">确认删除</button>
            <button class="btn" @click="cancelDelete">取消</button>
          </div>
        </div>
      </div>
    </section>
  </AdminUI>
</template>

<style scoped>
.topbar {
  position: sticky; top: 0; z-index: 10;
  display: flex; align-items: center; gap: 12px;
  padding: 14px 20px;
  border-bottom: 1px solid var(--line);
  background: color-mix(in oklab, var(--bg) 85%, transparent);
  backdrop-filter: blur(6px);
}
.topbar h1 { font-size: 1rem; margin: 0; color: var(--text); font-weight: 700; letter-spacing: .02em }

.block { padding: 20px; }

.add-user {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
}

.input {
  flex: 1;
  max-width: 300px;
  padding: 8px 12px;
  border-radius: 8px;
  border: 1px solid var(--line);
  background: var(--panel);
  color: var(--text);
  font-size: 0.875rem;
  outline: none;
  transition: border-color 0.15s;
}
.input:focus {
  border-color: var(--brand);
}

.btn {
  padding: 8px 16px;
  border-radius: 8px;
  border: 1px solid var(--line);
  background: var(--panel);
  color: var(--text);
  font-size: 0.875rem;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.btn:hover {
  background: rgba(255,255,255,.06);
  border-color: var(--brand);
}
.btn-primary {
  background: color-mix(in oklab, var(--brand) 20%, transparent);
  border-color: color-mix(in oklab, var(--brand) 40%, transparent);
}
.btn-primary:hover {
  background: color-mix(in oklab, var(--brand) 30%, transparent);
}
.btn-danger {
  border-color: rgba(239,68,68,.4);
  color: #f87171;
}
.btn-danger:hover {
  background: rgba(239,68,68,.15);
}

.error-msg {
  color: #f87171;
  font-size: 0.85rem;
  margin-bottom: 12px;
}

.user-table {
  width: 100%;
  border-collapse: collapse;
}
.user-table th,
.user-table td {
  padding: 10px 14px;
  text-align: left;
  border-bottom: 1px solid var(--line);
  font-size: 0.875rem;
}
.user-table th {
  color: var(--muted);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .08em;
  font-size: 0.75rem;
}
.user-table tr:hover td {
  background: rgba(255,255,255,.02);
}

.empty {
  display: grid; place-items: center;
  padding: 24px;
  border-radius: 12px;
  color: var(--muted);
  border: 1px dashed rgba(168,176,191,.3);
  background: var(--panel);
}

.confirm-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.6);
  display: grid;
  place-items: center;
  z-index: 1000;
}
.confirm-dialog {
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 24px;
  min-width: 320px;
  box-shadow: 0 12px 40px rgba(0,0,0,.5);
}
.confirm-dialog p {
  margin: 0 0 16px;
  color: var(--text);
  font-size: 0.9rem;
}
.confirm-actions {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
}
</style>
